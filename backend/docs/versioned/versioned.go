package versioned

import (
	"encoding/json"
	"strings"

	basedocs "mediguide/docs"

	"github.com/swaggo/swag"
)

type staticSpec struct {
	read func() string
}

func (s staticSpec) ReadDoc() string {
	return s.read()
}

func init() {
	swag.Register("all", staticSpec{read: func() string {
		return basedocs.SwaggerInfo.ReadDoc()
	}})
	swag.Register("v1", staticSpec{read: func() string {
		return filterDoc("/api/v1", "MediGuide Backend API - V1", "Legacy compatibility endpoints under /api/v1.")
	}})
	swag.Register("v2", staticSpec{read: func() string {
		return filterDoc("/api/v2", "MediGuide Backend API - V2", "Current backend API endpoints under /api/v2.")
	}})
}

func filterDoc(prefix, title, description string) string {
	raw := basedocs.SwaggerInfo.ReadDoc()

	var doc map[string]any
	if err := json.Unmarshal([]byte(raw), &doc); err != nil {
		return raw
	}

	filteredPaths := map[string]any{}
	usedTags := map[string]bool{}
	if paths, ok := doc["paths"].(map[string]any); ok {
		for path, value := range paths {
			if !strings.HasPrefix(path, prefix) {
				continue
			}
			filteredPaths[path] = value
			collectTags(value, usedTags)
		}
	}
	doc["paths"] = filteredPaths

	if info, ok := doc["info"].(map[string]any); ok {
		info["title"] = title
		info["description"] = description
	}

	if tags, ok := doc["tags"].([]any); ok {
		filteredTags := make([]any, 0, len(tags))
		for _, tag := range tags {
			tagMap, ok := tag.(map[string]any)
			if !ok {
				continue
			}
			name, _ := tagMap["name"].(string)
			if usedTags[name] {
				filteredTags = append(filteredTags, tag)
			}
		}
		doc["tags"] = filteredTags
	}

	out, err := json.Marshal(doc)
	if err != nil {
		return raw
	}
	return string(out)
}

func collectTags(pathItem any, usedTags map[string]bool) {
	pathMap, ok := pathItem.(map[string]any)
	if !ok {
		return
	}
	for _, operation := range pathMap {
		opMap, ok := operation.(map[string]any)
		if !ok {
			continue
		}
		rawTags, ok := opMap["tags"].([]any)
		if !ok {
			continue
		}
		for _, rawTag := range rawTags {
			tag, ok := rawTag.(string)
			if ok && tag != "" {
				usedTags[tag] = true
			}
		}
	}
}
