d = @destruct [a, b] = Dict(:a => 1, :b => 2)
@test d == Dict(:a => 1, :b => 2)
@test (a, b) == (1, 2)

@destruct [a] = Dict("a" => "foo")
@test a == "foo"

@destruct [foo = :a || 5, b = :b || 6, c || 7] = Dict(:a => 1)
@test (foo, b, c) == (1, 6, 7)

@destruct _.data = "foo"
@test _ == "foo"
@test data == "foo".data

@destruct _.(re, im) = Complex(1,2)
@test (re, im) == (1, 2)

@destruct [s.data = :a] = Dict(:a => "foo")
@test s == "foo"
@test data === s.data

@destruct x[a, [c, d] = b] = Dict(:a => 1, :b => Dict(:c => 2, :d => 3))
@test x == Dict(:a => 1, :b => Dict(:c => 2, :d => 3))
@test (a, c, d) == (1, 2, 3)
@test b == Dict(:c => 2, :d => 3)
