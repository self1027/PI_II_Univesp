package graphql

import (
	"testing"

	"legisanalytica/internal/activity"
	"legisanalytica/internal/expense"

	"github.com/graphql-go/graphql"
)

func queryData(t *testing.T, objectType *graphql.Object, value interface{}, query string) map[string]interface{} {
	t.Helper()
	root := graphql.NewObject(graphql.ObjectConfig{
		Name: "TestQuery",
		Fields: graphql.Fields{
			"registro": &graphql.Field{
				Type: objectType,
				Resolve: func(graphql.ResolveParams) (interface{}, error) {
					return value, nil
				},
			},
		},
	})
	schema, err := graphql.NewSchema(graphql.SchemaConfig{Query: root})
	if err != nil {
		t.Fatal(err)
	}
	result := graphql.Do(graphql.Params{Schema: schema, RequestString: query})
	if len(result.Errors) != 0 {
		t.Fatal(result.Errors)
	}
	data := result.Data.(map[string]interface{})
	return data["registro"].(map[string]interface{})
}

func TestApprovalPreservesUnknownResult(t *testing.T) {
	b := &schemaBuilder{}
	b.buildActivityTypes()
	approved, rejected := true, false
	for _, approval := range []*bool{nil, &approved, &rejected} {
		data := queryData(t, b.votacaoType, activity.Votacao{Approval: approval}, "{ registro { aprovacao } }")
		if approval == nil {
			if data["aprovacao"] != nil {
				t.Fatalf("unknown approval became %v", data["aprovacao"])
			}
		} else if data["aprovacao"] != *approval {
			t.Fatalf("approval = %v, want %v", data["aprovacao"], *approval)
		}
	}
}

func TestExpensePreservesMissingValueAndRealZero(t *testing.T) {
	b := &schemaBuilder{}
	b.buildExpenseTypes()
	zero := 0.0
	document := "10"
	data := queryData(t, b.expenseType, expense.Expense{
		IDDocument: &document,
		NetValue:   &zero,
	}, "{ registro { id_documento valor_documento valor_glosa valor_liquido valor_restituicao } }")
	if data["id_documento"] != "10" || data["valor_liquido"] != zero {
		t.Fatalf("document or zero value changed: %v", data)
	}
	for _, field := range []string{"valor_documento", "valor_glosa", "valor_restituicao"} {
		if data[field] != nil {
			t.Fatalf("missing %s became %v", field, data[field])
		}
	}
}
