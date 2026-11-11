package graphql

import "github.com/graphql-go/graphql"

func expenseQueryArgs(p graphql.ResolveParams) (string, *string, *string, *int, *int) {
	id := p.Args["id"].(string)

	var typeCode *string
	if val, ok := p.Args["type_code"].(string); ok {
		typeCode = &val
	}

	var house *string
	if val, ok := p.Args["casa"].(string); ok && val != "" {
		house = &val
	}

	var monthStart, monthEnd *int
	if val, ok := p.Args["mes_inicio"].(int); ok {
		monthStart = &val
	}
	if val, ok := p.Args["mes_fim"].(int); ok {
		monthEnd = &val
	}

	if monthStart != nil && monthEnd != nil && *monthStart > *monthEnd {
		*monthStart, *monthEnd = *monthEnd, *monthStart
	}

	return id, house, typeCode, monthStart, monthEnd
}

func (b *schemaBuilder) expenseQueries() graphql.Fields {
	return graphql.Fields{
		"despesas": &graphql.Field{
			Type: graphql.NewList(b.expenseType),

			Args: graphql.FieldConfigArgument{
				"id": &graphql.ArgumentConfig{
					Type: graphql.NewNonNull(graphql.String),
				},
				"limit": {
					Type:         graphql.Int,
					DefaultValue: 20,
				},
				"offset": {
					Type:         graphql.Int,
					DefaultValue: 0,
				},
				"type_code": {
					Type: graphql.String,
				},
				"casa": {
					Type: graphql.String,
				},
			},

			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				id := p.Args["id"].(string)

				limit, offset := paginationArgs(p)

				var typeCode *string
				if val, ok := p.Args["type_code"].(string); ok {
					typeCode = &val
				}

				var house *string
				if val, ok := p.Args["casa"].(string); ok && val != "" {
					house = &val
				}

				return b.ds.GetExpensesByPolitician(
					p.Context,
					id,
					house,
					limit,
					offset,
					typeCode,
				)
			},
		},
		"totalDespesas": &graphql.Field{
			Type: graphql.NewNonNull(graphql.Int),

			Args: graphql.FieldConfigArgument{
				"id": &graphql.ArgumentConfig{
					Type: graphql.NewNonNull(graphql.String),
				},
				"type_code": {
					Type: graphql.String,
				},
				"casa": {
					Type: graphql.String,
				},
			},

			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				id := p.Args["id"].(string)

				var typeCode *string
				if val, ok := p.Args["type_code"].(string); ok {
					typeCode = &val
				}

				var house *string
				if val, ok := p.Args["casa"].(string); ok && val != "" {
					house = &val
				}

				total, err := b.ds.CountExpensesByPolitician(
					p.Context,
					id,
					house,
					typeCode,
				)
				if err != nil {
					return nil, err
				}

				return int(total), nil
			},
		},
		"resumoDespesas": &graphql.Field{
			Type: graphql.NewList(b.expenseSummaryType),

			Args: graphql.FieldConfigArgument{
				"id": &graphql.ArgumentConfig{
					Type: graphql.NewNonNull(graphql.String),
				},
				"type_code": {
					Type: graphql.String,
				},
				"casa": {
					Type: graphql.String,
				},
				"mes_inicio": {
					Type: graphql.Int,
				},
				"mes_fim": {
					Type: graphql.Int,
				},
			},

			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				id, house, typeCode, monthStart, monthEnd := expenseQueryArgs(p)

				return b.ds.GetExpenseSummaryByPolitician(
					p.Context,
					id,
					house,
					typeCode,
					monthStart,
					monthEnd,
				)
			},
		},
		"estatisticasDespesas": &graphql.Field{
			Type: b.expenseStatsType,

			Args: graphql.FieldConfigArgument{
				"id": &graphql.ArgumentConfig{
					Type: graphql.NewNonNull(graphql.String),
				},
				"type_code": {
					Type: graphql.String,
				},
				"casa": {
					Type: graphql.String,
				},
				"mes_inicio": {
					Type: graphql.Int,
				},
				"mes_fim": {
					Type: graphql.Int,
				},
			},

			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				id, house, typeCode, monthStart, monthEnd := expenseQueryArgs(p)

				return b.ds.GetExpenseStatisticsByPolitician(
					p.Context,
					id,
					house,
					typeCode,
					monthStart,
					monthEnd,
				)
			},
		},
	}
}
func (b *schemaBuilder) buildExpenseTypes() {
	b.expenseKindType = graphql.NewObject(graphql.ObjectConfig{
		Name: "ExpenseType",
		Fields: graphql.Fields{
			"casa":        &graphql.Field{Type: graphql.String},
			"codigo_tipo": &graphql.Field{Type: graphql.String},
			"descricao":   &graphql.Field{Type: graphql.String},
		},
	})

	b.supplierType = graphql.NewObject(graphql.ObjectConfig{
		Name: "Supplier",
		Fields: graphql.Fields{
			"casa":     &graphql.Field{Type: graphql.String},
			"cnpj_cpf": &graphql.Field{Type: graphql.String},
			"nome":     &graphql.Field{Type: graphql.String},
		},
	})

	b.expenseSummaryType = graphql.NewObject(graphql.ObjectConfig{
		Name: "ExpenseCategorySummary",
		Fields: graphql.Fields{
			"categoria":  &graphql.Field{Type: graphql.String},
			"quantidade": &graphql.Field{Type: graphql.Int},
			"total":      &graphql.Field{Type: graphql.Float},
		},
	})

	b.expenseStatsType = graphql.NewObject(graphql.ObjectConfig{
		Name: "ExpenseStatistics",
		Fields: graphql.Fields{
			"total_despesas":     &graphql.Field{Type: graphql.Int},
			"total_liquido":      &graphql.Field{Type: graphql.Float},
			"meses_com_despesas": &graphql.Field{Type: graphql.Int},
			"ano_inicio":         &graphql.Field{Type: graphql.Int},
			"ano_fim":            &graphql.Field{Type: graphql.Int},
			"media_mensal":       &graphql.Field{Type: graphql.Float, Description: "Total dividido pelos meses com registros. Não é média por mês de exercício nem pelos 12 meses do ano."},
		},
	})

	b.expenseType = graphql.NewObject(graphql.ObjectConfig{
		Name: "Expense",
		Fields: graphql.Fields{
			"casa":              &graphql.Field{Type: graphql.String},
			"id_despesa":        &graphql.Field{Type: graphql.String},
			"id_documento":      &graphql.Field{Type: graphql.String, Description: "Documento de origem. Pode estar associado a vários movimentos de despesa."},
			"id_parlamentar":    &graphql.Field{Type: graphql.String},
			"ano":               &graphql.Field{Type: graphql.Int},
			"mes":               &graphql.Field{Type: graphql.Int},
			"data_emissao":      &graphql.Field{Type: graphql.String},
			"codigo_tipo":       &graphql.Field{Type: graphql.String},
			"cnpj_cpf":          &graphql.Field{Type: graphql.String},
			"valor_documento":   &graphql.Field{Type: graphql.Float},
			"valor_glosa":       &graphql.Field{Type: graphql.Float},
			"valor_liquido":     &graphql.Field{Type: graphql.Float},
			"valor_restituicao": &graphql.Field{Type: graphql.Float},
			"tipo": &graphql.Field{
				Type: b.expenseKindType,
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					exp := expenseFromSource(p.Source)
					if exp == nil {
						return nil, nil
					}
					return b.ds.GetExpenseType(p.Context, exp.House, exp.TypeCode)
				},
			},
			"fornecedor": &graphql.Field{
				Type: b.supplierType,
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					exp := expenseFromSource(p.Source)
					if exp == nil {
						return nil, nil
					}
					return b.ds.GetSupplier(p.Context, exp.House, exp.TaxID)
				},
			},
		},
	})
}
