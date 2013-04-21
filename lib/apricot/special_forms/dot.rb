module Apricot
  # (. receiver method args*)
  # (. receiver method args* & rest)
  # (. receiver method args* | block)
  # (. receiver method args* & rest | block)
  # (. receiver (method args*))
  # (. receiver (method args* & rest))
  # (. receiver (method args* | block))
  # (. receiver (method args* & rest | block))
  SpecialForm.define(:'.') do |g, args|
    g.compile_error "Too few arguments to send expression, expecting (. receiver method ...)" if args.count < 2

    # TODO: Don't convert to an array, just deal with the List.
    args = args.to_a

    receiver, method_or_list = args.shift(2)

    # Handle the (. receiver (method args*)) form
    if method_or_list.is_a? List
      method = method_or_list.elements.shift

      g.compile_error "Invalid send expression, expecting (. receiver (method ...))" unless args.empty?

      args = method_or_list.elements
    else
      method = method_or_list
    end

    g.compile_error "Method in send expression must be an identifier" unless method.is_a? Identifier

    block_arg = nil
    splat_arg = nil

    if args[-2].is_a?(Identifier) && args[-2].name == :|
      block_arg = args.last
      args.pop(2)
    end

    if args[-2].is_a?(Identifier) && args[-2].name == :&
      splat_arg = args.last
      args.pop(2)
    end

    args.each do |arg|
      next unless arg.is_a?(Identifier)
      g.compile_error "Incorrect use of & in send expression" if arg.name == :&
      g.compile_error "Incorrect use of | in send expression" if arg.name == :|
    end

    Compiler.bytecode(g ,receiver)

    if block_arg || splat_arg
      args.each {|a| Compiler.bytecode(g, a) }

      if splat_arg
        Compiler.bytecode(g, splat_arg)
        g.cast_array unless splat_arg.is_a?(Array)
      end

      if block_arg
        nil_block = g.new_label
        Compiler.bytecode(g, block_arg)
        g.dup
        g.is_nil
        g.git nil_block

        g.push_const :Proc

        g.swap
        g.send :__from_block__, 1

        nil_block.set!
      else
        g.push_nil
      end

      if splat_arg
        g.send_with_splat method.name, args.length
      else
        g.send_with_block method.name, args.length
      end

    elsif method.name == :new
      slow = g.new_label
      done = g.new_label

      g.dup # dup the receiver
      g.check_serial :new, Rubinius::CompiledMethod::KernelMethodSerial
      g.gif slow

      # fast path
      g.send :allocate, 0, true
      g.dup
      args.each {|a| Compiler.bytecode(g, a) }
      g.send :initialize, args.length, true
      g.pop

      g.goto done

      # slow path
      slow.set!
      args.each {|a| Compiler.bytecode(g, a) }
      g.send :new, args.length

      done.set!

    else
      args.each {|a| Compiler.bytecode(g, a) }
      g.send method.name, args.length
    end
  end
end
