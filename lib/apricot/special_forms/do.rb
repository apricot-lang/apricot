module Apricot
  # (do body*)
  SpecialForm.define(:do) do |g, args|
    if args.empty?
      g.push_nil
    else
      tail_position = g.tail_position?
      last_index = args.count - 1

      args.each_with_index do |a, i|
        g.pop unless i == 0

        if i == last_index && tail_position
          g.tail_position = true
        else
          g.tail_position = false
        end

        Compiler.bytecode(g, a)
      end
    end
  end
end
