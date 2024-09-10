function nodes()
    return {
        {
			is_expr = true,
			short = "i",
			name = "Identifier",
			fields = {
				{ name = "Value", type = "string" }
			}
		},
        {
			is_expr = true,
			short = "il",
			name = "IntegerLiteral",
			fields = {
				{ name = "Value", type = "int64" }
			}
		},
    }
end