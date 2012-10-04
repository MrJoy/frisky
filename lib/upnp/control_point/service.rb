require 'savon'
require_relative 'base'
require_relative 'error'


Savon.configure do |c|
  c.env_namespace = :s
end

begin
  require 'em-http'
  HTTPI.adapter = :em_http
rescue ArgumentError
  puts "Couldn't load HTTPI :em_http adapter."
  # Fail silently
end


module UPnP
  class ControlPoint

    # An object of this type functions as somewhat of a proxy to a UPnP device's
    # service.  The object sort of defines itself when you call #fetch; it
    # gets the description file from the device, parses it, populates its
    # attributes (as accessors) and defines singleton methods from the list of
    # actions that the service defines.
    #
    # After the fetch is done, you can call Ruby methods on the service and
    # expect a Ruby Hash back as a return value.  The methods will look just
    # the SOAP actions and will always return a Hash, where key/value pairs are
    # converted from the SOAP response; values are converted to the according
    # Ruby type based on <dataType> in the <serviceStateTable>.
    #
    # Types map like:
    #   * Integer
    #     * ui1
    #     * ui2
    #     * ui4
    #     * i1
    #     * i2
    #     * i4
    #     * int
    #   * Float
    #     * r4
    #     * r8
    #     * number
    #     * fixed.14.4
    #     * float
    #   * String
    #     * char
    #     * string
    #     * uuid
    #   * TrueClass
    #     * 1
    #     * true
    #     * yes
    #   * FalseClass
    #     * 0
    #     * false
    #     * no
    #
    # @example No "in" params
    #   my_service.GetSystemUpdateID    # => { "Id" => 1 }
    #
    class Service < Base
      include EventMachine::Deferrable
      include LogSwitch::Mixin

      #vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
      # Passed in by +service_list_info+
      #

      # @return [String] UPnP service type, including URN.
      attr_reader :service_type

      # @return [String] Service identifier, unique within this service's devices.
      attr_reader :service_id

      # @return [URI::HTTP] Service description URL.
      attr_reader :scpd_url

      # @return [URI::HTTP] Control URL.
      attr_reader :control_url

      # @return [URI::HTTP] Eventing URL.
      attr_reader :event_sub_url

      #
      # DONE +service_list_info+
      #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

      #vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
      # Determined by service description file
      #

      # @return [String]
      attr_reader :xmlns

      # @return [String]
      attr_reader :spec_version

      # @return [Array<Hash>]
      attr_reader :action_list

      # Probably don't need to keep this long-term; just adding for testing.
      attr_reader :service_state_table

      #
      # DONE description
      #^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

      # @return [Hash] The whole description... just in case.
      attr_reader :description

      # @param [String] device_base_url URL given (or otherwise determined) by
      #   <URLBase> from the device that owns the service.
      # @param [Hash] service_list_info Info given in the <serviceList> section
      #   of the device description.
      def initialize(device_base_url, service_list_info)
        @service_list_info = service_list_info
        @action_list = []
        @xmlns = ""
        extract_service_list_info(device_base_url)
      end

      # Fetches the service description file, parses it, extracts attributes
      # into accessors, and defines Ruby methods from SOAP actions.  Since this
      # is a long-ish process, this is done using EventMachine Deferrable
      # behavior.
      def fetch
        if @scpd_url.empty?
          log "<#{self.class}> NO SCPDURL to get the service description from.  Returning."
          set_deferred_success self
          return
        end

        description_getter = EventMachine::DefaultDeferrable.new
        log "<#{self.class}> Fetching service description with #{description_getter.object_id}"
        get_description(@scpd_url, description_getter)

        description_getter.errback do
          msg = "Failed getting service description."
          log "<#{self.class}> #{msg}", :error
          # @todo Should this return self? or should it succeed?
          set_deferred_status(:failed, msg)

          if ControlPoint.raise_on_remote_error
            raise ControlPoint::Error, msg
          end
        end

        description_getter.callback do |description|
          log "<#{self.class}> Service description received for #{description_getter.object_id}."
          @description = description
          @xmlns = @description[:scpd][:@xmlns]
          extract_spec_version
          extract_service_state_table

          if @description[:scpd][:actionList]
            log "<#{self.class}> Defining methods from action_list using [#{description_getter.object_id}]"
            define_methods_from_actions(@description[:scpd][:actionList][:action])
            configure_savon
          end

          set_deferred_status(:succeeded, self)
        end
      end

      private

      # Extracts all of the basic service information from the information
      # handed over from the device description about the service.  The actual
      # service description info gathering is *not* done here.
      #
      # @param [String] device_base_url The URLBase from the device.  Used to
      #   build absolute URLs for the service.
      def extract_service_list_info(device_base_url)
        @control_url = if @service_list_info[:controlURL]
          build_url(device_base_url, @service_list_info[:controlURL])
        else
          log "<#{self.class}> Required controlURL attribute is blank."
          ""
        end

        @event_sub_url = if @service_list_info[:eventSubURL]
          build_url(device_base_url, @service_list_info[:eventSubURL])
        else
          log "<#{self.class}> Required eventSubURL attribute is blank."
          ""
        end

        @service_type = @service_list_info[:serviceType]
        @service_id = @service_list_info[:serviceId]

        @scpd_url = if @service_list_info[:SCPDURL]
          build_url(device_base_url, @service_list_info[:SCPDURL])
        else
          log "<#{self.class}> Required SCPDURL attribute is blank."
          ""
        end
      end

      def extract_spec_version
        "#{@description[:scpd][:specVersion][:major]}.#{@description[:scpd][:specVersion][:minor]}"
      end

      def extract_service_state_table
        @service_state_table = if @description[:scpd][:serviceStateTable].is_a? Hash
          @description[:scpd][:serviceStateTable][:stateVariable]
        elsif @description[:scpd][:serviceStateTable].is_a? Array
          @description[:scpd][:serviceStateTable].map do |state|
            state[:stateVariable]
          end
        end
      end

      # Determines if <actionList> from the service description contains a
      # single action or multiple actions and delegates to create Ruby methods
      # accordingly.
      #
      # @param [Hash,Array] action_list The value from <scpd><actionList><action>
      #   from the service description.
      def define_methods_from_actions(action_list)
        if action_list.is_a? Hash
          @action_list << action_list
          define_method_from_action(action_list[:name].to_sym,
            action_list[:argumentList][:argument])
        elsif action_list.is_a? Array
          action_list.each do |action|
=begin
        in_args_count = action[:argumentList][:argument].find_all do |arg|
          arg[:direction] == 'in'
        end.size
=end
            @action_list << action
            define_method_from_action(action[:name].to_sym, action[:argumentList][:argument])
          end
        else
          log "<#{self.class}> Got actionList that's not an Array or Hash."
        end
      end

      # Defines a Ruby method from the SOAP action.  When called, the method
      # will return a key/value pair defined by the "out" argument name and
      # value.  The Ruby type of each value is determined from the
      # serviceStateTable.
      #
      # @param [Symbol] action_name The extracted value from <actionList>
      #   <action><name> from the spec.
      # @param [Hash,Array] argument_info The extracted values from
      #   <actionList><action><argumentList><argument> from the spec.
      def define_method_from_action(action_name, argument_info)
        define_singleton_method(action_name) do |*params|
          begin
            response = @soap_client.request(:u, action_name, "xmlns:u" => @service_type) do
              http.headers['SOAPACTION'] = "#{@service_type}##{action_name}"

              soap.body = params.inject({}) do |result, arg|
                result[:argument_name] = arg
                result
              end
            end
          rescue Savon::SOAP::Fault => ex
            hash = Nori.parse(ex.http.body)
            msg = <<-MSG
SOAP request failure!
HTTP response code: #{ex.http.code}
HTTP headers: #{ex.http.headers}
HTTP body: #{ex.http.body}
HTTP body as Hash: #{hash}
            MSG

            raise(ActionError, msg) if ControlPoint.raise_on_remote_error

            log "<#{self.class}> #{msg}"
            return hash[:Envelope][:Body]
          end

          if argument_info.is_a?(Hash) && argument_info[:direction] == "out"
            return_ruby_from_soap(action_name, response, argument_info)
          elsif argument_info.is_a? Array
            argument_info.map do |arg|
              if arg[:direction] == "out"
                return_ruby_from_soap(action_name, response, arg)
              end
            end
          else
            log "<#{self.class}> No args with direction 'out'"
          end
        end

        log "<#{self.class}> Defined method: #{action_name}"
      end

      # Uses the serviceStateTable to look up the output from the SOAP response
      # for the given action, then converts it to the according Ruby data type.
      #
      # @param [String] action_name The name of the SOAP action that was called
      #   for which this will get the response from.
      # @param [Savon::SOAP::Response] soap_response The response from making
      #   the SOAP call.
      # @param [Hash] out_argument The Hash that tells out the "out" argument
      #   which tells what data type to return.
      # @return [Hash] Key will be the "out" argument name as a Symbol and the
      #   key will be the value as its converted Ruby type.
      def return_ruby_from_soap(action_name, soap_response, out_argument)
        out_arg_name = out_argument[:name]
        #puts "out arg name: #{out_arg_name}"

        related_state_variable = out_argument[:relatedStateVariable]
        #puts "related state var: #{related_state_variable}"

        state_variable = @service_state_table.find do |state_var_hash|
          state_var_hash[:name] == related_state_variable
        end

        #puts "state var: #{state_variable}"

        int_types = %w[ui1 ui2 ui4 i1 i2 i4 int]
        float_types = %w[r4 r8 number fixed.14.4 float]
        string_types = %w[char string uuid]
        true_types = %w[1 true yes]
        false_types = %w[0 false no]

        if int_types.include? state_variable[:dataType]
          {
            out_arg_name.to_sym => soap_response.
              hash[:Envelope][:Body]["#{action_name}Response".to_sym][out_arg_name.to_sym].to_i
          }
        elsif string_types.include? state_variable[:dataType]
          return {} if soap_response.hash.empty?
          {
            out_arg_name.to_sym => soap_response.
              hash[:Envelope][:Body]["#{action_name}Response".to_sym][out_arg_name.to_sym].to_s
          }
        elsif float_types.include? state_variable[:dataType]
          {
            out_arg_name.to_sym => soap_response.
              hash[:Envelope][:Body]["#{action_name}Response".to_sym][out_arg_name.to_sym].to_f
          }
        else
          log "<#{self.class}> Got SOAP response that I dunno what to do with: #{soap_response.hash}"
        end
      end

      def configure_savon
        @soap_client = Savon.client do |wsdl|
          wsdl.endpoint = @control_url
          wsdl.namespace = @service_type
        end
      end
    end
  end
end
