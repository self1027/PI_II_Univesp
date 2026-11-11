package expense

import (
	"context"
	"fmt"

	"gorm.io/gorm"
)

type Repository interface {
	GetExpensesByPolitician(ctx context.Context, id string, house *string, limit, offset int, typeCode *string) ([]Expense, error)
	CountExpensesByPolitician(ctx context.Context, id string, house *string, typeCode *string) (int64, error)
	GetExpenseSummaryByPolitician(ctx context.Context, id string, house *string, typeCode *string, monthStart, monthEnd *int) ([]ExpenseCategorySummary, error)
	GetExpenseStatisticsByPolitician(ctx context.Context, id string, house *string, typeCode *string, monthStart, monthEnd *int) (*ExpenseStatistics, error)
	GetExpenseValue(ctx context.Context, idExpense string) (*ExpenseValue, error)
	GetExpenseType(ctx context.Context, house, typeCode string) (*ExpenseType, error)
	GetSupplier(ctx context.Context, house, taxID string) (*Supplier, error)
}

type repository struct {
	db *gorm.DB
}

func NewRepository(db *gorm.DB) Repository {
	return &repository{db: db}
}

func (r *repository) expensesByPoliticianQuery(ctx context.Context, id string, house *string, typeCode *string) *gorm.DB {
	query := r.db.WithContext(ctx).
		Table("public.despesa AS d").
		// Na Câmara, despesa.id_parlamentar é o código CEAP e precisa ser
		// convertido via identificador_parlamentar, preenchido com ideCadastro.
		// No Senado, despesa.id_parlamentar já é o id da API.
		Joins(`LEFT JOIN public.identificador_parlamentar ip
               ON ip.casa = d.casa
              AND ip.sistema = 'CEAP'
              AND ip.codigo_externo = d.id_parlamentar`).
		Where(`(d.casa = 'CAMARA' AND ip.id_parlamentar = ?)
            OR (d.casa <> 'CAMARA' AND d.id_parlamentar = ?)`, id, id)

	if house != nil {
		query = query.Where("d.casa = ?", *house)
	}

	if typeCode != nil {
		query = query.Where("d.codigo_tipo = ?", *typeCode)
	}

	return query
}

func (r *repository) GetExpensesByPolitician(ctx context.Context, id string, house *string, limit, offset int, typeCode *string) ([]Expense, error) {
	var expenses []Expense
	err := r.expensesByPoliticianQuery(ctx, id, house, typeCode).
		Select(`
            d.*,
            v.valor_documento,
            v.valor_glosa,
            v.valor_liquido,
            v.valor_restituicao
        `).
		Joins("LEFT JOIN public.valor_despesa v ON v.casa = d.casa AND v.id_despesa = d.id_despesa").
		Order("d.data_emissao DESC NULLS LAST, d.id_despesa DESC").
		Limit(limit).
		Offset(offset).
		Find(&expenses).Error

	if err != nil {
		return nil, fmt.Errorf("error fetching expenses: %w", err)
	}
	return expenses, nil
}

func (r *repository) CountExpensesByPolitician(ctx context.Context, id string, house *string, typeCode *string) (int64, error) {
	var total int64
	err := r.expensesByPoliticianQuery(ctx, id, house, typeCode).Count(&total).Error
	if err != nil {
		return 0, fmt.Errorf("error counting expenses: %w", err)
	}
	return total, nil
}

func applyMonthRange(query *gorm.DB, monthStart, monthEnd *int) *gorm.DB {
	if monthStart != nil {
		query = query.Where("d.mes >= ?", *monthStart)
	}
	if monthEnd != nil {
		query = query.Where("d.mes <= ?", *monthEnd)
	}
	return query
}

func (r *repository) GetExpenseSummaryByPolitician(ctx context.Context, id string, house *string, typeCode *string, monthStart, monthEnd *int) ([]ExpenseCategorySummary, error) {
	var summary []ExpenseCategorySummary
	query := applyMonthRange(
		r.expensesByPoliticianQuery(ctx, id, house, typeCode),
		monthStart,
		monthEnd,
	)

	err := query.
		Select(`
            COALESCE(t.descricao, d.codigo_tipo, 'Categoria não informada') AS categoria,
            COUNT(*) AS quantidade,
            COALESCE(SUM(v.valor_liquido), 0)::float8 AS total
        `).
		Joins("LEFT JOIN public.valor_despesa v ON v.casa = d.casa AND v.id_despesa = d.id_despesa").
		Joins("LEFT JOIN public.tipo_despesa t ON t.casa = d.casa AND t.codigo_tipo = d.codigo_tipo").
		Group("COALESCE(t.descricao, d.codigo_tipo, 'Categoria não informada')").
		Order("total DESC").
		Scan(&summary).Error
	if err != nil {
		return nil, fmt.Errorf("error fetching expense summary: %w", err)
	}
	return summary, nil
}

func (r *repository) GetExpenseStatisticsByPolitician(ctx context.Context, id string, house *string, typeCode *string, monthStart, monthEnd *int) (*ExpenseStatistics, error) {
	var stats ExpenseStatistics
	query := applyMonthRange(
		r.expensesByPoliticianQuery(ctx, id, house, typeCode),
		monthStart,
		monthEnd,
	)

	err := query.
		Select(`
            COUNT(*) AS total_despesas,
            COALESCE(SUM(v.valor_liquido), 0)::float8 AS total_liquido,
            COUNT(DISTINCT (d.ano, d.mes)) AS meses_com_despesas,
            COALESCE(MIN(d.ano), 0) AS ano_inicio,
            COALESCE(MAX(d.ano), 0) AS ano_fim
        `).
		Joins("LEFT JOIN public.valor_despesa v ON v.casa = d.casa AND v.id_despesa = d.id_despesa").
		Scan(&stats).Error
	if err != nil {
		return nil, fmt.Errorf("error fetching expense statistics: %w", err)
	}

	if stats.Months > 0 {
		stats.MonthlyAverage = stats.TotalValue / float64(stats.Months)
	}

	return &stats, nil
}

func (r *repository) GetExpenseValue(ctx context.Context, idExpense string) (*ExpenseValue, error) {
	var ev ExpenseValue
	err := r.db.WithContext(ctx).Where("id_despesa = ?", idExpense).First(&ev).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, fmt.Errorf("expense value not found: %w", err)
		}
		return nil, fmt.Errorf("error fetching expense value: %w", err)
	}
	return &ev, nil
}

func (r *repository) GetExpenseType(ctx context.Context, house, typeCode string) (*ExpenseType, error) {
	var et ExpenseType
	err := r.db.WithContext(ctx).Where("casa = ? AND codigo_tipo = ?", house, typeCode).First(&et).Error
	if err != nil {
		return nil, err
	}
	return &et, nil
}

func (r *repository) GetSupplier(ctx context.Context, house, taxID string) (*Supplier, error) {
	var s Supplier
	err := r.db.WithContext(ctx).Where("casa = ? AND cnpj_cpf = ?", house, taxID).First(&s).Error
	if err != nil {
		return nil, err
	}
	return &s, nil
}
