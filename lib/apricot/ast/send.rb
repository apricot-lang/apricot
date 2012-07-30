module Apricot
  module AST

    # An auxiliary node for handling special send expression forms:
    # 
    # (.method)
    # (Foo. )
    # (Foo/bar )
    # 
    class Send < Identifier
      attr_reader :receiver
      attr_reader :message

      def initialize(line, receiver, message)
        rec_name = case receiver
                   when Constant
                     receiver.names.join('::')
                   when Identifier
                     receiver.name
                   end
        if receiver.nil? # (.foo )
          name = ".#{message}".to_sym
        elsif message == :new # (Foo. )
          name = "#{rec_name}.".to_sym
        else # (Foo/bar )
          name = "#{rec_name}/#{message}".to_sym
        end
        super(line, name)
        @receiver = receiver
        @message = message
      end
    end
  end
end
