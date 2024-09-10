function nodes(m)
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
			is_expr = false,
			short = "rs",
			name = "ReturnStatement",
			fields = {
				{ name = "ReturnValue", type = "Expression" }
			},
			string_fn = m.return_statement_string,
		},
		{
			is_expr = false,
			short = "es",
			name = "ExpressionStatement",
			fields = {
				{ name = "Expression", type = "Expression" }
			},
			string_fn = m.expr_statement_string,
		},
		{
			is_expr = true,
			short = "il",
			name = "IntegerLiteral",
			fields = {
				{ name = "Value", type = "int64" }
			}
		},
		{
			is_expr = true,
			short = "pe",
			name = "PrefixExpression",
			fields = {
				{ name = "Operator", type = "string" },
				{ name = "Right",    type = "Expression" },
			},
			string_fn = m.prefix_expr_string,
		}
	}
end
