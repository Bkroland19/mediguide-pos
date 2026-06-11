package services

type PageInput struct {
	Page    int `json:"page"`
	PerPage int `json:"per_page"`
}

type PageResult[T any] struct {
	Items      []T   `json:"items"`
	Page       int   `json:"page"`
	PerPage    int   `json:"per_page"`
	TotalItems int64 `json:"total_items"`
	TotalPages int   `json:"total_pages"`
}

func (in PageInput) Normalize(defaultPerPage, maxPerPage int) PageInput {
	page := in.Page
	if page < 1 {
		page = 1
	}

	perPage := in.PerPage
	if perPage < 1 {
		perPage = defaultPerPage
	}
	if maxPerPage > 0 && perPage > maxPerPage {
		perPage = maxPerPage
	}

	return PageInput{
		Page:    page,
		PerPage: perPage,
	}
}

func (in PageInput) Offset() int {
	page := in.Page
	if page < 1 {
		page = 1
	}
	perPage := in.PerPage
	if perPage < 1 {
		perPage = 1
	}
	return (page - 1) * perPage
}

func NewPageResult[T any](items []T, page PageInput, totalItems int64) *PageResult[T] {
	normalized := page
	if normalized.Page < 1 {
		normalized.Page = 1
	}
	if normalized.PerPage < 1 {
		normalized.PerPage = 1
	}
	totalPages := 0
	if totalItems > 0 {
		totalPages = int((totalItems + int64(normalized.PerPage) - 1) / int64(normalized.PerPage))
	}

	return &PageResult[T]{
		Items:      items,
		Page:       normalized.Page,
		PerPage:    normalized.PerPage,
		TotalItems: totalItems,
		TotalPages: totalPages,
	}
}
