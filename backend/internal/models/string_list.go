package models

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"strings"
)

type StringList []string

func (s StringList) Value() (driver.Value, error) {
	if s == nil {
		return nil, nil
	}
	return json.Marshal([]string(s))
}

func (s *StringList) Scan(value any) error {
	if value == nil {
		*s = nil
		return nil
	}

	var data []byte
	switch v := value.(type) {
	case []byte:
		data = v
	case string:
		data = []byte(v)
	default:
		return fmt.Errorf("unsupported StringList scan type %T", value)
	}

	if len(data) == 0 {
		*s = nil
		return nil
	}

	var out []string
	if err := json.Unmarshal(data, &out); err != nil {
		return err
	}
	*s = normalizeStringList(out)
	return nil
}

func (s *StringList) UnmarshalJSON(data []byte) error {
	trimmed := strings.TrimSpace(string(data))
	if trimmed == "" || trimmed == "null" {
		*s = nil
		return nil
	}

	if strings.HasPrefix(trimmed, "\"") {
		var single string
		if err := json.Unmarshal(data, &single); err != nil {
			return err
		}
		if strings.TrimSpace(single) == "" {
			*s = nil
			return nil
		}
		*s = normalizeStringList([]string{single})
		return nil
	}

	var many []string
	if err := json.Unmarshal(data, &many); err != nil {
		return err
	}
	*s = normalizeStringList(many)
	return nil
}

func (s StringList) MarshalJSON() ([]byte, error) {
	if s == nil {
		return []byte("null"), nil
	}
	return json.Marshal([]string(s))
}

func normalizeStringList(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	normalized := make([]string, 0, len(values))
	seen := make(map[string]struct{}, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		if _, ok := seen[trimmed]; ok {
			continue
		}
		seen[trimmed] = struct{}{}
		normalized = append(normalized, trimmed)
	}
	if len(normalized) == 0 {
		return nil
	}
	return normalized
}
