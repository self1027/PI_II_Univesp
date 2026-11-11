package expense

import "time"

type Expense struct {
	House        string    `gorm:"column:casa" json:"casa"`
	IDExpense    string    `gorm:"column:id_despesa;primaryKey" json:"id_despesa"`
	IDDocument   *string   `gorm:"column:id_documento" json:"id_documento"`
	IDPolitician string    `gorm:"column:id_parlamentar" json:"id_parlamentar"`
	Year         int       `gorm:"column:ano" json:"ano"`
	Month        int       `gorm:"column:mes" json:"mes"`
	IssueDate    time.Time `gorm:"column:data_emissao" json:"data_emissao"`
	TypeCode     string    `gorm:"column:codigo_tipo" json:"codigo_tipo"`
	TaxID        string    `gorm:"column:cnpj_cpf" json:"cnpj_cpf"`
	// Ponteiros distinguem valor ausente de um zero informado pela fonte.
	DocumentValue *float64 `gorm:"column:valor_documento" json:"valor_documento"`
	GlosaValue    *float64 `gorm:"column:valor_glosa" json:"valor_glosa"`
	NetValue      *float64 `gorm:"column:valor_liquido" json:"valor_liquido"`
	ReturnedValue *float64 `gorm:"column:valor_restituicao" json:"valor_restituicao"`
}

func (Expense) TableName() string {
	return "public.despesa"
}

type ExpenseType struct {
	House       string `gorm:"column:casa;primaryKey" json:"casa"`
	TypeCode    string `gorm:"column:codigo_tipo;primaryKey" json:"codigo_tipo"`
	Description string `gorm:"column:descricao" json:"descricao"`
}

func (ExpenseType) TableName() string {
	return "public.tipo_despesa"
}

type Supplier struct {
	House  string `gorm:"column:casa;primaryKey" json:"casa"`
	TaxID  string `gorm:"column:cnpj_cpf;primaryKey" json:"cnpj_cpf"`
	Name   string `gorm:"column:nome" json:"nome"`
	IDLote string `gorm:"column:id_lote" json:"id_lote"`
}

func (Supplier) TableName() string {
	return "public.fornecedor"
}

type ExpenseCategorySummary struct {
	Category string  `gorm:"column:categoria" json:"categoria"`
	Quantity int64   `gorm:"column:quantidade" json:"quantidade"`
	Total    float64 `gorm:"column:total" json:"total"`
}

type ExpenseStatistics struct {
	TotalExpenses  int64   `gorm:"column:total_despesas" json:"total_despesas"`
	TotalValue     float64 `gorm:"column:total_liquido" json:"total_liquido"`
	Months         int64   `gorm:"column:meses_com_despesas" json:"meses_com_despesas"`
	StartYear      int64   `gorm:"column:ano_inicio" json:"ano_inicio"`
	EndYear        int64   `gorm:"column:ano_fim" json:"ano_fim"`
	MonthlyAverage float64 `gorm:"-" json:"media_mensal"`
}

type ExpenseValue struct {
	IDExpense     string   `gorm:"column:id_despesa;primaryKey" json:"id_despesa"`
	DocumentValue *float64 `gorm:"column:valor_documento" json:"valor_documento"`
	GlosaValue    *float64 `gorm:"column:valor_glosa" json:"valor_glosa"`
	NetValue      *float64 `gorm:"column:valor_liquido" json:"valor_liquido"`
	ReturnedValue *float64 `gorm:"column:valor_restituicao" json:"valor_restituicao"`
}

func (ExpenseValue) TableName() string {
	return "public.valor_despesa"
}
