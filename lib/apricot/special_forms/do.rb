module Apricot
  # (do body*)
  SpecialForm.define(:do) do |g, args|
    if args.empty?
      g.push_nil
    else
      args[0..-2].each do |a|
        a.bytecode(g)
        g.pop
      end
      args.last.bytecode(g)
    end
  end
end
