module Apricot
  # (do body*)
  SpecialForm.define(:do) do |g, args|
    if args.empty?
      g.push_nil
    else
      args.each_with_index do |a, i|
        g.pop unless i == 0
        Compiler.bytecode(g, a)
      end
    end
  end
end
