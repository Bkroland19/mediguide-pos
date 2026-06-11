package services

import "testing"

func TestPageInputNormalize(t *testing.T) {
	in := PageInput{Page: 0, PerPage: 999}
	got := in.Normalize(20, 100)

	if got.Page != 1 {
		t.Fatalf("expected normalized page 1, got %d", got.Page)
	}
	if got.PerPage != 100 {
		t.Fatalf("expected normalized per_page 100, got %d", got.PerPage)
	}
}

func TestNewPageResult(t *testing.T) {
	result := NewPageResult([]string{"a", "b"}, PageInput{Page: 2, PerPage: 10}, 25)

	if result.Page != 2 {
		t.Fatalf("expected page 2, got %d", result.Page)
	}
	if result.PerPage != 10 {
		t.Fatalf("expected per_page 10, got %d", result.PerPage)
	}
	if result.TotalItems != 25 {
		t.Fatalf("expected total_items 25, got %d", result.TotalItems)
	}
	if result.TotalPages != 3 {
		t.Fatalf("expected total_pages 3, got %d", result.TotalPages)
	}
	if len(result.Items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(result.Items))
	}
}
