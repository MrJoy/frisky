require 'savon'
require_relative 'base'


Savon.configure do |c|
  c.env_namespace = :s
end

begin
  require 'em-http'
  HTTPI.adapter = :em_http
rescue ArgumentError
  # Fail silently
end


module UPnP
  class ControlPoint
    class Service < Base

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

      # @return [Hash<String,Array<String>>]
      attr_reader :actions

      # @return [URI::HTTP] Base URL for this service's device.
      attr_reader :device_base_url

      attr_reader :description

      # Probably don't need to keep this long-term; just adding for testing.
      attr_reader :service_state_table

      def initialize(device_base_url, device_service)
        @device_base_url = device_base_url
        @scpd_url = build_url(@device_base_url, device_service[:SCPDURL])
        @control_url = build_url(@device_base_url, device_service[:controlURL])
        @event_sub_url = build_url(@device_base_url, device_service[:eventSubURL])

        @service_type = device_service[:serviceType]
        @service_id = device_service[:serviceId]

        @description = get_description(@scpd_url)

        @service_state_table = @description[:scpd][:serviceStateTable][:stateVariable]
        @actions = []
        define_methods_from_actions(@description[:scpd][:actionList][:action])

        @soap_client = Savon.client do |wsdl|
          wsdl.endpoint = @control_url
          wsdl.namespace = @service_type
        end
      end

      private

      def define_methods_from_actions(action_list)
        action_list.each do |action|
=begin
        in_args_count = action[:argumentList][:argument].find_all do |arg|
          arg[:direction] == 'in'
        end.size
=end
          @actions << action

          define_singleton_method(action[:name].to_sym) do |*params|
            st = @service_type

            response = @soap_client.request(:u, action[:name], "xmlns:u" => @service_type) do
              http.headers['SOAPACTION'] = "#{st}##{action[:name]}"

              soap.body = params.inject({}) do |result, arg|
                puts "arg: #{arg}"
                result[:argument_name] = arg

                result
              end
            end

            argument = action[:argumentList][:argument]

            if argument.is_a?(Hash) && argument[:direction] == "out"
              return_ruby_from_soap(action[:name], response, argument)
            elsif argument.is_a? Array
              argument.map do |a|
                if a[:direction] == "out"
                  return_ruby_from_soap(action[:name], response, a)
                end
              end
            else
              puts "No args with direction 'out'"
            end
          end
        end
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

        if state_variable[:dataType] == "ui4"
          {
            out_arg_name.to_sym => soap_response.
              hash[:Envelope][:Body]["#{action_name}Response".to_sym][out_arg_name.to_sym].to_i
          }
        elsif state_variable[:dataType] == "string"
          {
            out_arg_name.to_sym => soap_response.
              hash[:Envelope][:Body]["#{action_name}Response".to_sym][out_arg_name.to_sym].to_s
          }
        end
      end
    end
  end
end
