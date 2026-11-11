package graphql

import "github.com/graphql-go/graphql"

func (b *schemaBuilder) activityQueries() graphql.Fields {
	return graphql.Fields{
		"atividade": b.activityQueryField(),
		"votos":     b.votesQueryField(),

		"todas_proposicoes": b.allPropositionsQueryField(),
		"todos_votos":       b.allVotesQueryField(),

		"votos_da_votacao":       b.votesByVotacaoQueryField(),
		"votacoes_da_proposicao": b.votacoesByPropositionQueryField(),
	}
}

func (b *schemaBuilder) activityQueryField() *graphql.Field {
	return &graphql.Field{
		Type: graphql.NewList(b.propositionType),

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
			"somente_votadas": {
				Type:         graphql.Boolean,
				DefaultValue: false,
			},
		},

		Resolve: func(p graphql.ResolveParams) (interface{}, error) {
			id := p.Args["id"].(string)
			limit, offset := paginationArgs(p)
			onlyVoted, _ := p.Args["somente_votadas"].(bool)

			return b.as.GetPropositionsByPolitician(
				p.Context,
				id,
				limit,
				offset,
				onlyVoted,
			)
		},
	}
}

func (b *schemaBuilder) votesQueryField() *graphql.Field {
	return &graphql.Field{
		Type: graphql.NewList(b.voteType),

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
			"vote_code": {
				Type: graphql.String,
			},
		},

		Resolve: func(p graphql.ResolveParams) (interface{}, error) {
			id := p.Args["id"].(string)
			limit, offset := paginationArgs(p)

			var voteCode *string
			if val, ok := p.Args["vote_code"].(string); ok {
				voteCode = &val
			}

			return b.as.GetVotesByPolitician(
				p.Context,
				id,
				limit,
				offset,
				voteCode,
			)
		},
	}
}

func (b *schemaBuilder) allPropositionsQueryField() *graphql.Field {
	return &graphql.Field{
		Type: graphql.NewList(b.propositionType),

		Args: graphql.FieldConfigArgument{
			"limit": {
				Type:         graphql.Int,
				DefaultValue: 20,
			},
			"offset": {
				Type:         graphql.Int,
				DefaultValue: 0,
			},
		},

		Resolve: func(p graphql.ResolveParams) (interface{}, error) {
			limit, offset := paginationArgs(p)

			return b.as.ListAllPropositions(
				p.Context,
				limit,
				offset,
			)
		},
	}
}

func (b *schemaBuilder) allVotesQueryField() *graphql.Field {
	return &graphql.Field{
		Type: graphql.NewList(b.voteType),

		Args: graphql.FieldConfigArgument{
			"limit": {
				Type:         graphql.Int,
				DefaultValue: 20,
			},
			"offset": {
				Type:         graphql.Int,
				DefaultValue: 0,
			},
		},

		Resolve: func(p graphql.ResolveParams) (interface{}, error) {
			limit, offset := paginationArgs(p)

			return b.as.ListAllVotes(
				p.Context,
				limit,
				offset,
			)
		},
	}
}

func (b *schemaBuilder) votesByVotacaoQueryField() *graphql.Field {
	return &graphql.Field{
		Type: graphql.NewList(b.voteType),

		Args: graphql.FieldConfigArgument{
			"casa": &graphql.ArgumentConfig{
				Type: graphql.NewNonNull(graphql.String),
			},
			"id_votacao": &graphql.ArgumentConfig{
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
			"vote_code": {
				Type: graphql.String,
			},
		},

		Resolve: func(p graphql.ResolveParams) (interface{}, error) {
			house := p.Args["casa"].(string)
			idVote := p.Args["id_votacao"].(string)
			limit, offset := paginationArgs(p)

			var voteCode *string
			if val, ok := p.Args["vote_code"].(string); ok {
				voteCode = &val
			}

			return b.as.GetVotesByVotacao(
				p.Context,
				house,
				idVote,
				limit,
				offset,
				voteCode,
			)
		},
	}
}

func (b *schemaBuilder) votacoesByPropositionQueryField() *graphql.Field {
	return &graphql.Field{
		Type: graphql.NewList(b.votacaoType),

		Args: graphql.FieldConfigArgument{
			"casa": &graphql.ArgumentConfig{
				Type: graphql.NewNonNull(graphql.String),
			},
			"id_proposicao": &graphql.ArgumentConfig{
				Type: graphql.NewNonNull(graphql.String),
			},
		},

		Resolve: func(p graphql.ResolveParams) (interface{}, error) {
			house := p.Args["casa"].(string)
			idProp := p.Args["id_proposicao"].(string)

			return b.as.GetVotacoesByProposition(
				p.Context,
				house,
				idProp,
			)
		},
	}
}

func (b *schemaBuilder) buildActivityTypes() {
	b.propositionType = graphql.NewObject(graphql.ObjectConfig{
		Name: "Proposition",
		Fields: graphql.Fields{
			"casa":              &graphql.Field{Type: graphql.String},
			"id_proposicao":     &graphql.Field{Type: graphql.String},
			"sigla_tipo":        &graphql.Field{Type: graphql.String},
			"numero":            &graphql.Field{Type: graphql.Int},
			"ano":               &graphql.Field{Type: graphql.Int},
			"ementa":            &graphql.Field{Type: graphql.String},
			"data_apresentacao": &graphql.Field{Type: graphql.String},
			"tem_votacao":       &graphql.Field{Type: graphql.Boolean, Description: "Existe votação vinculada na base; false não comprova ausência de votação na fonte."},
		},
	})

	b.votacaoType = graphql.NewObject(graphql.ObjectConfig{
		Name: "Votacao",
		Fields: graphql.Fields{
			"casa":               &graphql.Field{Type: graphql.String},
			"id_votacao":         &graphql.Field{Type: graphql.String},
			"data_votacao":       &graphql.Field{Type: graphql.String},
			"sigla_orgao":        &graphql.Field{Type: graphql.String},
			"aprovacao":          &graphql.Field{Type: graphql.Boolean, Description: "Resultado desta votação: true, false ou null quando desconhecido. Não indica aprovação final da proposição."},
			"resultado_original": &graphql.Field{Type: graphql.String},
			"descricao":          &graphql.Field{Type: graphql.String},
			"votos_sim":          &graphql.Field{Type: graphql.Int},
			"votos_nao":          &graphql.Field{Type: graphql.Int},
			"votos_outros":       &graphql.Field{Type: graphql.Int},
			"proposicoes": &graphql.Field{
				Type: graphql.NewList(b.propositionType),
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					v := votacaoFromSource(p.Source)
					if v == nil {
						return nil, nil
					}
					return b.as.GetPropositionsByVote(p.Context, v.House, v.IDVote)
				},
			},
		},
	})

	b.voteKindType = graphql.NewObject(graphql.ObjectConfig{
		Name: "VoteType",
		Fields: graphql.Fields{
			"casa":        &graphql.Field{Type: graphql.String},
			"codigo_voto": &graphql.Field{Type: graphql.String},
			"descricao":   &graphql.Field{Type: graphql.String},
		},
	})

	b.voteType = graphql.NewObject(graphql.ObjectConfig{
		Name: "Vote",
		Fields: graphql.Fields{
			"casa":           &graphql.Field{Type: graphql.String},
			"id_votacao":     &graphql.Field{Type: graphql.String},
			"id_parlamentar": &graphql.Field{Type: graphql.String},
			"codigo_voto":    &graphql.Field{Type: graphql.String},
			"partido":        &graphql.Field{Type: graphql.String, Description: "Partido informado no registro do voto."},
			"uf":             &graphql.Field{Type: graphql.String, Description: "UF informada no registro do voto."},
			"votacao": &graphql.Field{
				Type: b.votacaoType,
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					v := voteFromSource(p.Source)
					if v == nil {
						return nil, nil
					}
					return b.as.GetVotacao(p.Context, v.House, v.IDVote)
				},
			},
			"tipo": &graphql.Field{
				Type: b.voteKindType,
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					v := voteFromSource(p.Source)
					if v == nil {
						return nil, nil
					}
					return b.as.GetVoteType(p.Context, v.House, v.VoteCode)
				},
			},
		},
	})
}
