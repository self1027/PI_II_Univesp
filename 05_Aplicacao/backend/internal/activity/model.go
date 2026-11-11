package activity

import "time"

type Proposition struct {
	House            string    `gorm:"column:casa" json:"casa"`
	IDProposition    string    `gorm:"column:id_proposicao;primaryKey" json:"id_proposicao"`
	TypeAcronym      string    `gorm:"column:sigla_tipo" json:"sigla_tipo"`
	Number           *int      `gorm:"column:numero" json:"numero"`
	Year             *int      `gorm:"column:ano" json:"ano"`
	Summary          string    `gorm:"column:ementa" json:"ementa"`
	PresentationDate time.Time `gorm:"column:data_apresentacao" json:"data_apresentacao"`
	HasVote          bool      `gorm:"column:tem_votacao" json:"tem_votacao"`
}

func (Proposition) TableName() string {
	return "public.proposicao"
}

type Vote struct {
	House        string  `gorm:"column:casa" json:"casa"`
	IDVote       string  `gorm:"column:id_votacao;primaryKey" json:"id_votacao"`
	IDPolitician string  `gorm:"column:id_parlamentar" json:"id_parlamentar"`
	VoteCode     string  `gorm:"column:codigo_voto" json:"codigo_voto"`
	Party        *string `gorm:"column:partido" json:"partido"`
	State        *string `gorm:"column:uf" json:"uf"`
}

func (Vote) TableName() string {
	return "public.voto"
}

type VoteType struct {
	House       string `gorm:"column:casa;primaryKey" json:"casa"`
	VoteCode    string `gorm:"column:codigo_voto;primaryKey" json:"codigo_voto"`
	Description string `gorm:"column:descricao" json:"descricao"`
}

func (VoteType) TableName() string {
	return "public.tipo_voto"
}

type Votacao struct {
	House    string    `gorm:"column:casa;primaryKey" json:"casa"`
	IDVote   string    `gorm:"column:id_votacao;primaryKey" json:"id_votacao"`
	VoteDate time.Time `gorm:"column:data_votacao" json:"data_votacao"`
	Organ    string    `gorm:"column:sigla_orgao" json:"sigla_orgao"`
	// nil preserva o resultado desconhecido, que é diferente de rejeição (false).
	Approval    *bool   `gorm:"column:aprovacao" json:"aprovacao"`
	Result      *string `gorm:"column:resultado_original" json:"resultado_original"`
	Description string  `gorm:"column:descricao" json:"descricao"`
	YesVotes    int     `gorm:"column:votos_sim" json:"votos_sim"`
	NoVotes     int     `gorm:"column:votos_nao" json:"votos_nao"`
	OtherVotes  int     `gorm:"column:votos_outros" json:"votos_outros"`
}

func (Votacao) TableName() string {
	return "public.votacao"
}

type VotacaoProposicao struct {
	House         string `gorm:"column:casa;primaryKey" json:"casa"`
	IDVote        string `gorm:"column:id_votacao;primaryKey" json:"id_votacao"`
	IDProposition string `gorm:"column:id_proposicao;primaryKey" json:"id_proposicao"`
}

func (VotacaoProposicao) TableName() string {
	return "public.votacao_proposicao"
}
