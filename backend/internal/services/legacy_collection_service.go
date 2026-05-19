package services

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"mediguide/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

var (
	ErrLegacyCollectionNotFound   = errors.New("legacy collection not found")
	ErrLegacyCollectionAuthNeeded = errors.New("legacy collection requires authentication")
	ErrLegacyCollectionForbidden  = errors.New("legacy collection forbidden")
	ErrLegacyCollectionWrite      = errors.New("legacy collection write unsupported")
	ErrLegacyCollectionInvalid    = errors.New("legacy collection invalid payload")
)

type LegacyCollectionService struct {
	DB *gorm.DB
}

type LegacyListInput struct {
	Page    int
	PerPage int
	Search  string
	Filters map[string]string
}

type LegacyListResult struct {
	Success    bool             `json:"success"`
	Collection string           `json:"collection"`
	Page       int              `json:"page"`
	PerPage    int              `json:"per_page"`
	TotalItems int64            `json:"total_items"`
	Items      []map[string]any `json:"items"`
}

type LegacyItemResult struct {
	Success    bool           `json:"success"`
	Collection string         `json:"collection"`
	Item       map[string]any `json:"item"`
}

type legacyAccessMode string

const (
	legacyAccessPublic legacyAccessMode = "public"
	legacyAccessAuth   legacyAccessMode = "auth"
	legacyAccessUser   legacyAccessMode = "user"
)

type legacyCollectionSpec struct {
	Table         string
	IDColumn      string
	Select        string
	DefaultOrder  string
	SearchColumns []string
	FilterColumns map[string]string
	Access        legacyAccessMode
	Joins         []string
	ApplyScopes   func(*gorm.DB) *gorm.DB
	ApplyUser     func(*gorm.DB, string) *gorm.DB
}

func (s LegacyCollectionService) List(collection string, in LegacyListInput, userID string) (*LegacyListResult, error) {
	spec, ok := legacyCollectionSpecs[collection]
	if !ok {
		return nil, ErrLegacyCollectionNotFound
	}
	if err := validateLegacyAccess(spec, userID); err != nil {
		return nil, err
	}

	page := in.Page
	if page < 1 {
		page = 1
	}
	perPage := in.PerPage
	if perPage < 1 {
		perPage = 20
	}
	if perPage > 100 {
		perPage = 100
	}

	baseQuery := s.buildQuery(spec, userID)
	baseQuery = applyLegacySearch(baseQuery, spec.SearchColumns, in.Search)
	baseQuery = applyLegacyFilters(baseQuery, spec.FilterColumns, in.Filters)

	var total int64
	countQuery := baseQuery.Session(&gorm.Session{})
	if err := countQuery.Distinct(spec.IDColumn).Count(&total).Error; err != nil {
		return nil, err
	}

	items := []map[string]any{}
	dataQuery := baseQuery.Session(&gorm.Session{})
	if err := dataQuery.
		Select(spec.Select).
		Order(spec.DefaultOrder).
		Limit(perPage).
		Offset((page - 1) * perPage).
		Find(&items).Error; err != nil {
		return nil, err
	}

	return &LegacyListResult{
		Success:    true,
		Collection: collection,
		Page:       page,
		PerPage:    perPage,
		TotalItems: total,
		Items:      items,
	}, nil
}

func (s LegacyCollectionService) Get(collection, id, userID string) (*LegacyItemResult, error) {
	spec, ok := legacyCollectionSpecs[collection]
	if !ok {
		return nil, ErrLegacyCollectionNotFound
	}
	if err := validateLegacyAccess(spec, userID); err != nil {
		return nil, err
	}

	item := map[string]any{}
	query := s.buildQuery(spec, userID).
		Select(spec.Select).
		Where(spec.IDColumn+" = ?", id)
	if err := query.Take(&item).Error; err != nil {
		return nil, err
	}

	return &LegacyItemResult{
		Success:    true,
		Collection: collection,
		Item:       item,
	}, nil
}

func (s LegacyCollectionService) Create(collection string, payload map[string]any, userID string) (*LegacyItemResult, error) {
	spec, ok := legacyCollectionSpecs[collection]
	if !ok {
		return nil, ErrLegacyCollectionNotFound
	}
	if err := validateLegacyAccess(spec, userID); err != nil {
		return nil, err
	}

	switch collection {
	case "support_tickets":
		return s.createSupportTicket(payload, userID)
	case "support_ticket_replies":
		return s.createSupportTicketReply(payload, userID)
	case "conversations":
		return s.createConversation(payload, userID)
	case "messages":
		return s.createMessage(payload, userID)
	case "reading_progress":
		return s.createReadingProgress(payload, userID)
	case "calculator_usage_logs":
		return s.createUsageLog(collection, payload, userID)
	case "guideline_usage_logs":
		return s.createUsageLog(collection, payload, userID)
	case "drug_usage_logs":
		return s.createUsageLog(collection, payload, userID)
	case "abbreviation_usage_logs":
		return s.createUsageLog(collection, payload, userID)
	case "consultant_usage_logs":
		return s.createUsageLog(collection, payload, userID)
	case "facility_usage_logs":
		return s.createUsageLog(collection, payload, userID)
	case "ai_usage_logs":
		return s.createUsageLog(collection, payload, userID)
	default:
		return nil, ErrLegacyCollectionWrite
	}
}

func (s LegacyCollectionService) Update(collection, id string, payload map[string]any, userID string) (*LegacyItemResult, error) {
	spec, ok := legacyCollectionSpecs[collection]
	if !ok {
		return nil, ErrLegacyCollectionNotFound
	}
	if err := validateLegacyAccess(spec, userID); err != nil {
		return nil, err
	}

	switch collection {
	case "users":
		return s.updateUser(id, payload, userID)
	case "conversations":
		return s.updateConversation(id, payload, userID)
	case "messages":
		return s.updateMessage(id, payload, userID)
	case "reading_progress":
		return s.updateReadingProgress(id, payload, userID)
	case "calculator_usage_logs":
		return s.updateUsageLog(collection, id, payload, userID)
	default:
		return nil, ErrLegacyCollectionWrite
	}
}

func (s LegacyCollectionService) buildQuery(spec legacyCollectionSpec, userID string) *gorm.DB {
	query := s.DB.Table(spec.Table)
	for _, join := range spec.Joins {
		query = query.Joins(join)
	}
	if spec.ApplyScopes != nil {
		query = spec.ApplyScopes(query)
	}
	if spec.ApplyUser != nil && strings.TrimSpace(userID) != "" {
		query = spec.ApplyUser(query, userID)
	}
	return query
}

func (s LegacyCollectionService) createSupportTicket(payload map[string]any, userID string) (*LegacyItemResult, error) {
	row := map[string]any{
		"id":          uuid.New(),
		"user_id":     mustUUID(userID),
		"subject":     firstPayloadString(payload, "subject"),
		"description": firstPayloadString(payload, "description"),
		"status":      defaultString(firstPayloadString(payload, "status"), "open"),
		"priority":    defaultString(firstPayloadString(payload, "priority"), "normal"),
		"category":    nullableString(firstPayloadString(payload, "category")),
		"created_at":  time.Now().UTC(),
		"updated_at":  time.Now().UTC(),
	}
	if row["subject"] == "" || row["description"] == "" {
		return nil, ErrLegacyCollectionInvalid
	}
	if err := s.DB.Table("support_tickets").Create(&row).Error; err != nil {
		return nil, err
	}
	return s.Get("support_tickets", row["id"].(uuid.UUID).String(), userID)
}

func (s LegacyCollectionService) createSupportTicketReply(payload map[string]any, userID string) (*LegacyItemResult, error) {
	ticketID, err := parsePayloadUUID(payload, "ticket_id")
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}
	if err := s.ensureTicketAccess(ticketID, userID); err != nil {
		return nil, err
	}
	message := firstPayloadString(payload, "message")
	if message == "" {
		return nil, ErrLegacyCollectionInvalid
	}
	row := map[string]any{
		"id":          uuid.New(),
		"ticket_id":   ticketID,
		"user_id":     mustUUID(userID),
		"message":     message,
		"is_internal": false,
		"created_at":  time.Now().UTC(),
		"updated_at":  time.Now().UTC(),
	}
	if err := s.DB.Table("support_ticket_replies").Create(&row).Error; err != nil {
		return nil, err
	}
	return s.Get("support_ticket_replies", row["id"].(uuid.UUID).String(), userID)
}

func (s LegacyCollectionService) createConversation(payload map[string]any, userID string) (*LegacyItemResult, error) {
	p1, err := parsePayloadUUIDAny(payload, "participant1_user_id", "participant1")
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}
	p2, err := parsePayloadUUIDAny(payload, "participant2_user_id", "participant2")
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}
	currentUserID := mustUUID(userID)
	if p1 != currentUserID && p2 != currentUserID {
		return nil, ErrLegacyCollectionForbidden
	}

	existingID, found, err := s.findConversationID(p1, p2)
	if err != nil {
		return nil, err
	}
	if found {
		return s.Get("conversations", existingID.String(), userID)
	}

	row := map[string]any{
		"id":                   uuid.New(),
		"participant1_user_id": p1,
		"participant2_user_id": p2,
		"last_activity":        nullableString(firstPayloadStringAny(payload, "last_activity")),
		"created_at":           time.Now().UTC(),
		"updated_at":           time.Now().UTC(),
	}
	if err := s.DB.Table("conversations").Create(&row).Error; err != nil {
		return nil, err
	}
	return s.Get("conversations", row["id"].(uuid.UUID).String(), userID)
}

func (s LegacyCollectionService) createMessage(payload map[string]any, userID string) (*LegacyItemResult, error) {
	conversationID, err := parsePayloadUUIDAny(payload, "conversation_id", "conversation")
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}
	if err := s.ensureConversationAccess(conversationID, userID); err != nil {
		return nil, err
	}
	senderID, err := parsePayloadUUIDAny(payload, "sender_user_id", "sender")
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}
	if senderID != mustUUID(userID) {
		return nil, ErrLegacyCollectionForbidden
	}
	content := firstPayloadString(payload, "content")
	if content == "" {
		return nil, ErrLegacyCollectionInvalid
	}

	row := map[string]any{
		"id":               uuid.New(),
		"conversation_id":  conversationID,
		"sender_user_id":   senderID,
		"content":          content,
		"message_type":     nullableString(firstPayloadStringAny(payload, "message_type")),
		"attachments_json": jsonbValue(firstPayloadValue(payload, "attachments_json", "attachments")),
		"read_by_json":     jsonbValue(firstPayloadValue(payload, "read_by_json", "read_by")),
		"reactions_json":   jsonbValue(firstPayloadValue(payload, "reactions_json", "reactions")),
		"is_edited":        boolPayload(payload, "is_edited", false),
		"edited_at":        nullableString(firstPayloadStringAny(payload, "edited_at")),
		"created_at":       time.Now().UTC(),
		"updated_at":       time.Now().UTC(),
	}
	if replyID, ok := optionalPayloadUUIDAny(payload, "reply_to_id", "reply_to"); ok {
		row["reply_to_id"] = replyID
	}

	if err := s.DB.Table("messages").Create(&row).Error; err != nil {
		return nil, err
	}

	_ = s.DB.Table("conversations").Where("id = ?", conversationID).Updates(map[string]any{
		"last_activity": time.Now().UTC().Format(time.RFC3339),
		"updated_at":    time.Now().UTC(),
	}).Error

	return s.Get("messages", row["id"].(uuid.UUID).String(), userID)
}

func (s LegacyCollectionService) createReadingProgress(payload map[string]any, userID string) (*LegacyItemResult, error) {
	docID, err := parsePayloadUUIDAny(payload, "guideline_document_id", "guideline_id")
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}

	if existingID, found, err := s.findReadingProgressID(docID, mustUUID(userID)); err != nil {
		return nil, err
	} else if found {
		return s.updateReadingProgress(existingID.String(), payload, userID)
	}

	row := map[string]any{
		"id":                    uuid.New(),
		"user_id":               mustUUID(userID),
		"guideline_document_id": docID,
		"progress_percentage":   floatPayload(payload, "progress_percentage", 0),
		"current_section":       nullableString(firstPayloadStringAny(payload, "current_section")),
		"last_read_at":          nullableString(firstPayloadStringAny(payload, "last_read_at")),
		"is_bookmarked":         boolPayload(payload, "is_bookmarked", false),
		"reading_time_seconds":  nullableIntPayload(payload, "reading_time_seconds"),
		"created_at":            time.Now().UTC(),
		"updated_at":            time.Now().UTC(),
	}
	if err := s.DB.Table("reading_progress").Create(&row).Error; err != nil {
		return nil, err
	}
	return s.Get("reading_progress", row["id"].(uuid.UUID).String(), userID)
}

func (s LegacyCollectionService) createUsageLog(collection string, payload map[string]any, userID string) (*LegacyItemResult, error) {
	row := map[string]any{
		"id":         uuid.New(),
		"user_id":    mustUUID(userID),
		"created_at": time.Now().UTC(),
		"updated_at": time.Now().UTC(),
	}
	switch collection {
	case "calculator_usage_logs":
		id, err := parsePayloadUUIDAny(payload, "calculator_id")
		if err != nil {
			return nil, ErrLegacyCollectionInvalid
		}
		row["calculator_id"] = id
		row["session_start"] = firstPayloadStringAny(payload, "session_start")
		row["session_end"] = nullableString(firstPayloadStringAny(payload, "session_end"))
		row["calculator_type"] = defaultString(firstPayloadStringAny(payload, "calculator_type"), "calculator")
		if row["session_start"] == "" {
			return nil, ErrLegacyCollectionInvalid
		}
	case "guideline_usage_logs":
		id, err := parsePayloadUUIDAny(payload, "guideline_document_id", "guideline_id")
		if err != nil {
			return nil, ErrLegacyCollectionInvalid
		}
		row["guideline_document_id"] = id
	case "drug_usage_logs":
		id, err := parsePayloadUUIDAny(payload, "drug_id")
		if err != nil {
			return nil, ErrLegacyCollectionInvalid
		}
		row["drug_id"] = id
	case "abbreviation_usage_logs":
		id, err := parsePayloadUUIDAny(payload, "abbreviation_id")
		if err != nil {
			return nil, ErrLegacyCollectionInvalid
		}
		row["abbreviation_id"] = id
	case "consultant_usage_logs":
		id, err := parsePayloadUUIDAny(payload, "consultant_id")
		if err != nil {
			return nil, ErrLegacyCollectionInvalid
		}
		row["consultant_id"] = id
	case "facility_usage_logs":
		id, err := parsePayloadUUIDAny(payload, "facility_id")
		if err != nil {
			return nil, ErrLegacyCollectionInvalid
		}
		row["facility_id"] = id
	case "ai_usage_logs":
	default:
		return nil, ErrLegacyCollectionWrite
	}

	if err := s.DB.Table(collection).Create(&row).Error; err != nil {
		return nil, err
	}
	return s.Get(collection, row["id"].(uuid.UUID).String(), userID)
}

func (s LegacyCollectionService) updateUser(id string, payload map[string]any, userID string) (*LegacyItemResult, error) {
	if strings.TrimSpace(id) != strings.TrimSpace(userID) {
		return nil, ErrLegacyCollectionForbidden
	}

	updates := map[string]any{}
	copyStringUpdate(payload, updates, "name")
	copyStringUpdate(payload, updates, "phone")
	copyNullableStringUpdate(payload, updates, "alternative_phone")
	copyNullableStringUpdate(payload, updates, "facility_id")
	copyNullableStringUpdate(payload, updates, "address")
	copyNullableStringUpdate(payload, updates, "city")
	copyNullableStringUpdate(payload, updates, "state")
	copyNullableStringUpdate(payload, updates, "country")
	copyNullableStringUpdate(payload, updates, "postal_code")
	copyNullableStringUpdate(payload, updates, "license_number")
	copyNullableStringUpdate(payload, updates, "organization")
	copyNullableStringUpdate(payload, updates, "department")
	copyNullableStringUpdate(payload, updates, "job_title")
	copyNullableStringUpdate(payload, updates, "preferred_language")
	copyNullableStringUpdate(payload, updates, "timezone")
	copyNullableStringUpdate(payload, updates, "notes")
	if specialization, ok := payload["specialization"]; ok {
		list, err := stringListPayload(specialization)
		if err != nil {
			return nil, ErrLegacyCollectionInvalid
		}
		updates["specialization_json"] = models.StringList(list)
	}
	if len(updates) == 0 {
		return nil, ErrLegacyCollectionInvalid
	}
	updates["updated_at"] = time.Now().UTC()
	if err := s.DB.Model(&models.User{}).Where("id = ?", mustUUID(userID)).Updates(updates).Error; err != nil {
		return nil, err
	}

	var user models.User
	if err := s.DB.Preload("Roles.Permissions").First(&user, "id = ?", mustUUID(userID)).Error; err != nil {
		return nil, err
	}
	item, err := structToMap(user)
	if err != nil {
		return nil, err
	}
	return &LegacyItemResult{Success: true, Collection: "users", Item: item}, nil
}

func (s LegacyCollectionService) updateConversation(id string, payload map[string]any, userID string) (*LegacyItemResult, error) {
	conversationID, err := uuid.Parse(id)
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}
	if err := s.ensureConversationAccess(conversationID, userID); err != nil {
		return nil, err
	}
	updates := map[string]any{}
	copyNullableStringUpdateAny(payload, updates, "last_activity")
	if len(updates) == 0 {
		return nil, ErrLegacyCollectionInvalid
	}
	updates["updated_at"] = time.Now().UTC()
	if err := s.DB.Table("conversations").Where("id = ?", conversationID).Updates(updates).Error; err != nil {
		return nil, err
	}
	return s.Get("conversations", id, userID)
}

func (s LegacyCollectionService) updateMessage(id string, payload map[string]any, userID string) (*LegacyItemResult, error) {
	messageID, err := uuid.Parse(id)
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}
	if err := s.ensureMessageAccess(messageID, userID); err != nil {
		return nil, err
	}
	updates := map[string]any{}
	copyStringUpdate(payload, updates, "content")
	if value, ok := firstExistingPayloadValue(payload, "read_by_json", "read_by"); ok {
		updates["read_by_json"] = jsonbValue(value)
	}
	if value, ok := firstExistingPayloadValue(payload, "reactions_json", "reactions"); ok {
		updates["reactions_json"] = jsonbValue(value)
	}
	if value, ok := payload["is_edited"]; ok {
		updates["is_edited"] = value
	}
	copyNullableStringUpdateAny(payload, updates, "edited_at")
	if len(updates) == 0 {
		return nil, ErrLegacyCollectionInvalid
	}
	updates["updated_at"] = time.Now().UTC()
	if err := s.DB.Table("messages").Where("id = ?", messageID).Updates(updates).Error; err != nil {
		return nil, err
	}
	return s.Get("messages", id, userID)
}

func (s LegacyCollectionService) updateReadingProgress(id string, payload map[string]any, userID string) (*LegacyItemResult, error) {
	rowID, err := uuid.Parse(id)
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}
	if !s.ownsRow("reading_progress", rowID, userID) {
		return nil, ErrLegacyCollectionForbidden
	}
	updates := map[string]any{}
	copyNullableStringUpdateAny(payload, updates, "current_section")
	if value, ok := payload["progress_percentage"]; ok {
		updates["progress_percentage"] = value
	}
	copyNullableStringUpdateAny(payload, updates, "last_read_at")
	if value, ok := payload["is_bookmarked"]; ok {
		updates["is_bookmarked"] = value
	}
	if value, ok := payload["reading_time_seconds"]; ok {
		updates["reading_time_seconds"] = value
	}
	if len(updates) == 0 {
		return nil, ErrLegacyCollectionInvalid
	}
	updates["updated_at"] = time.Now().UTC()
	if err := s.DB.Table("reading_progress").Where("id = ?", rowID).Updates(updates).Error; err != nil {
		return nil, err
	}
	return s.Get("reading_progress", id, userID)
}

func (s LegacyCollectionService) updateUsageLog(collection, id string, payload map[string]any, userID string) (*LegacyItemResult, error) {
	rowID, err := uuid.Parse(id)
	if err != nil {
		return nil, ErrLegacyCollectionInvalid
	}
	if !s.ownsRow(collection, rowID, userID) {
		return nil, ErrLegacyCollectionForbidden
	}
	updates := map[string]any{}
	if collection == "calculator_usage_logs" {
		copyNullableStringUpdate(payload, updates, "session_end")
	}
	if len(updates) == 0 {
		return nil, ErrLegacyCollectionInvalid
	}
	updates["updated_at"] = time.Now().UTC()
	if err := s.DB.Table(collection).Where("id = ?", rowID).Updates(updates).Error; err != nil {
		return nil, err
	}
	return s.Get(collection, id, userID)
}

func (s LegacyCollectionService) ensureTicketAccess(ticketID uuid.UUID, userID string) error {
	var count int64
	if err := s.DB.Table("support_tickets").
		Where("id = ? AND deleted_at IS NULL AND (user_id::text = ? OR assigned_to::text = ?)", ticketID, userID, userID).
		Count(&count).Error; err != nil {
		return err
	}
	if count == 0 {
		return ErrLegacyCollectionForbidden
	}
	return nil
}

func (s LegacyCollectionService) ensureConversationAccess(conversationID uuid.UUID, userID string) error {
	var count int64
	if err := s.DB.Table("conversations").
		Where("id = ? AND deleted_at IS NULL AND (participant1_user_id::text = ? OR participant2_user_id::text = ?)", conversationID, userID, userID).
		Count(&count).Error; err != nil {
		return err
	}
	if count == 0 {
		return ErrLegacyCollectionForbidden
	}
	return nil
}

func (s LegacyCollectionService) ensureMessageAccess(messageID uuid.UUID, userID string) error {
	var count int64
	if err := s.DB.Table("messages m").
		Joins("JOIN conversations c ON c.id = m.conversation_id").
		Where("m.id = ? AND m.deleted_at IS NULL AND (c.participant1_user_id::text = ? OR c.participant2_user_id::text = ?)", messageID, userID, userID).
		Count(&count).Error; err != nil {
		return err
	}
	if count == 0 {
		return ErrLegacyCollectionForbidden
	}
	return nil
}

func (s LegacyCollectionService) ownsRow(table string, rowID uuid.UUID, userID string) bool {
	var count int64
	err := s.DB.Table(table).
		Where("id = ? AND deleted_at IS NULL AND user_id::text = ?", rowID, userID).
		Count(&count).Error
	return err == nil && count > 0
}

func (s LegacyCollectionService) findConversationID(participant1, participant2 uuid.UUID) (uuid.UUID, bool, error) {
	var row struct {
		ID uuid.UUID `gorm:"column:id"`
	}
	err := s.DB.Table("conversations").
		Select("id").
		Where("deleted_at IS NULL").
		Where(
			"((participant1_user_id = ? AND participant2_user_id = ?) OR (participant1_user_id = ? AND participant2_user_id = ?))",
			participant1, participant2, participant2, participant1,
		).
		Take(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return uuid.Nil, false, nil
	}
	if err != nil {
		return uuid.Nil, false, err
	}
	return row.ID, true, nil
}

func (s LegacyCollectionService) findReadingProgressID(guidelineDocumentID, userID uuid.UUID) (uuid.UUID, bool, error) {
	var row struct {
		ID uuid.UUID `gorm:"column:id"`
	}
	err := s.DB.Table("reading_progress").
		Select("id").
		Where("deleted_at IS NULL AND user_id = ? AND guideline_document_id = ?", userID, guidelineDocumentID).
		Order("updated_at DESC").
		Take(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return uuid.Nil, false, nil
	}
	if err != nil {
		return uuid.Nil, false, err
	}
	return row.ID, true, nil
}

func parsePayloadUUID(payload map[string]any, key string) (uuid.UUID, error) {
	value := firstPayloadString(payload, key)
	if value == "" {
		return uuid.Nil, errors.New("missing uuid")
	}
	return uuid.Parse(value)
}

func parsePayloadUUIDAny(payload map[string]any, keys ...string) (uuid.UUID, error) {
	value := firstPayloadStringAny(payload, keys...)
	if value == "" {
		return uuid.Nil, errors.New("missing uuid")
	}
	return uuid.Parse(value)
}

func optionalPayloadUUID(payload map[string]any, key string) (uuid.UUID, bool) {
	value := firstPayloadString(payload, key)
	if value == "" {
		return uuid.Nil, false
	}
	id, err := uuid.Parse(value)
	if err != nil {
		return uuid.Nil, false
	}
	return id, true
}

func optionalPayloadUUIDAny(payload map[string]any, keys ...string) (uuid.UUID, bool) {
	value := firstPayloadStringAny(payload, keys...)
	if value == "" {
		return uuid.Nil, false
	}
	id, err := uuid.Parse(value)
	if err != nil {
		return uuid.Nil, false
	}
	return id, true
}

func firstPayloadValue(payload map[string]any, keys ...string) any {
	for _, key := range keys {
		if value, ok := payload[key]; ok {
			return value
		}
	}
	return nil
}

func firstExistingPayloadValue(payload map[string]any, keys ...string) (any, bool) {
	for _, key := range keys {
		if value, ok := payload[key]; ok {
			return value, true
		}
	}
	return nil, false
}

func firstPayloadString(payload map[string]any, key string) string {
	value, ok := payload[key]
	if !ok || value == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprintf("%v", value))
}

func firstPayloadStringAny(payload map[string]any, keys ...string) string {
	for _, key := range keys {
		if value := firstPayloadString(payload, key); value != "" {
			return value
		}
		if raw, ok := payload[key]; ok && raw != nil {
			return strings.TrimSpace(fmt.Sprintf("%v", raw))
		}
	}
	return ""
}

func nullableString(value string) any {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return strings.TrimSpace(value)
}

func defaultString(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return strings.TrimSpace(value)
}

func copyStringUpdate(payload map[string]any, updates map[string]any, key string) {
	if value := firstPayloadString(payload, key); value != "" {
		updates[key] = value
	}
}

func copyNullableStringUpdate(payload map[string]any, updates map[string]any, key string) {
	if raw, ok := payload[key]; ok {
		value := strings.TrimSpace(fmt.Sprintf("%v", raw))
		if value == "" {
			updates[key] = nil
			return
		}
		updates[key] = value
	}
}

func copyNullableStringUpdateAny(payload map[string]any, updates map[string]any, keys ...string) {
	for _, key := range keys {
		if raw, ok := payload[key]; ok {
			value := strings.TrimSpace(fmt.Sprintf("%v", raw))
			targetKey := key
			if len(keys) > 0 {
				targetKey = keys[0]
			}
			if value == "" {
				updates[targetKey] = nil
				return
			}
			updates[targetKey] = value
			return
		}
	}
}

func boolPayload(payload map[string]any, key string, fallback bool) bool {
	value, ok := payload[key]
	if !ok || value == nil {
		return fallback
	}
	switch typed := value.(type) {
	case bool:
		return typed
	case string:
		return strings.EqualFold(strings.TrimSpace(typed), "true")
	default:
		return fallback
	}
}

func floatPayload(payload map[string]any, key string, fallback float64) float64 {
	value, ok := payload[key]
	if !ok || value == nil {
		return fallback
	}
	switch typed := value.(type) {
	case float64:
		return typed
	case float32:
		return float64(typed)
	case int:
		return float64(typed)
	case int64:
		return float64(typed)
	default:
		return fallback
	}
}

func nullableIntPayload(payload map[string]any, key string) any {
	value, ok := payload[key]
	if !ok || value == nil {
		return nil
	}
	switch typed := value.(type) {
	case int:
		return typed
	case int64:
		return typed
	case float64:
		return int64(typed)
	default:
		return nil
	}
}

func jsonbValue(value any) any {
	if value == nil {
		return nil
	}
	switch typed := value.(type) {
	case map[string]any, []any:
		return typed
	default:
		return value
	}
}

func stringListPayload(value any) ([]string, error) {
	switch typed := value.(type) {
	case []string:
		return typed, nil
	case []any:
		out := make([]string, 0, len(typed))
		for _, item := range typed {
			out = append(out, strings.TrimSpace(fmt.Sprintf("%v", item)))
		}
		return out, nil
	case string:
		trimmed := strings.TrimSpace(typed)
		if trimmed == "" {
			return []string{}, nil
		}
		return []string{trimmed}, nil
	default:
		return nil, errors.New("invalid string list")
	}
}

func mustUUID(raw string) uuid.UUID {
	id, _ := uuid.Parse(strings.TrimSpace(raw))
	return id
}

func structToMap(v any) (map[string]any, error) {
	data, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	out := map[string]any{}
	if err := json.Unmarshal(data, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func validateLegacyAccess(spec legacyCollectionSpec, userID string) error {
	if (spec.Access == legacyAccessAuth || spec.Access == legacyAccessUser) && strings.TrimSpace(userID) == "" {
		return ErrLegacyCollectionAuthNeeded
	}
	return nil
}

func applyLegacySearch(query *gorm.DB, columns []string, raw string) *gorm.DB {
	term := strings.TrimSpace(raw)
	if term == "" || len(columns) == 0 {
		return query
	}

	parts := make([]string, 0, len(columns))
	args := make([]any, 0, len(columns))
	like := "%" + term + "%"
	for _, column := range columns {
		parts = append(parts, column+" ILIKE ?")
		args = append(args, like)
	}
	return query.Where("("+strings.Join(parts, " OR ")+")", args...)
}

func applyLegacyFilters(query *gorm.DB, columns map[string]string, filters map[string]string) *gorm.DB {
	if len(columns) == 0 || len(filters) == 0 {
		return query
	}
	for key, value := range filters {
		column, ok := columns[key]
		if !ok {
			continue
		}
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		if strings.EqualFold(trimmed, "null") {
			query = query.Where(column + " IS NULL")
			continue
		}
		query = query.Where(column+" = ?", trimmed)
	}
	return query
}

var legacyCollectionSpecs = map[string]legacyCollectionSpec{
	"medical_guidelines": {
		Table:        "medical_guidelines mg",
		IDColumn:     "mg.id",
		Select:       "mg.*, gi.title AS index_item_title",
		DefaultOrder: "mg.updated_at DESC",
		SearchColumns: []string{
			"mg.condition_name", "coalesce(mg.icd10_code, '')", "coalesce(mg.target_population, '')",
		},
		FilterColumns: map[string]string{
			"priority": "mg.priority",
			"status":   "mg.status",
		},
		Access: legacyAccessPublic,
		Joins:  []string{"LEFT JOIN guideline_index gi ON gi.id = mg.index_item_id"},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("mg.deleted_at IS NULL").Where("(mg.is_published = ? OR mg.status = ?)", true, "published")
		},
	},
	"drugs": {
		Table:        "drugs d",
		IDColumn:     "d.id",
		Select:       "d.*, dc.name AS drug_class_name, tc.name AS therapeutic_category_name",
		DefaultOrder: "d.name ASC",
		SearchColumns: []string{
			"d.name", "coalesce(d.brand_names, '')", "coalesce(d.description, '')", "coalesce(d.indications, '')", "coalesce(d.search_keywords, '')",
		},
		FilterColumns: map[string]string{
			"status":                  "d.status",
			"review_status":           "d.review_status",
			"drug_class_id":           "d.drug_class_id::text",
			"therapeutic_category_id": "d.therapeutic_category_id::text",
		},
		Access: legacyAccessPublic,
		Joins: []string{
			"LEFT JOIN drug_classes dc ON dc.id = d.drug_class_id",
			"LEFT JOIN therapeutic_categories tc ON tc.id = d.therapeutic_category_id",
		},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("d.deleted_at IS NULL").Where("d.status = ?", "active")
		},
	},
	"calculators": {
		Table:        "calculators c",
		IDColumn:     "c.id",
		Select:       "c.*",
		DefaultOrder: "c.name ASC",
		SearchColumns: []string{
			"c.name", "coalesce(c.description, '')", "coalesce(c.type, '')",
		},
		FilterColumns: map[string]string{
			"status":   "c.status",
			"type":     "c.type",
			"featured": "c.featured::text",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("c.deleted_at IS NULL").Where("coalesce(c.status, '') = ?", "active")
		},
	},
	"abbreviations": {
		Table:        "abbreviations a",
		IDColumn:     "a.id",
		Select:       "a.*",
		DefaultOrder: "a.abbreviation ASC",
		SearchColumns: []string{
			"a.abbreviation", "a.meaning", "coalesce(a.description, '')",
		},
		FilterColumns: map[string]string{
			"common_usage": "a.common_usage::text",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("a.deleted_at IS NULL")
		},
	},
	"emergency_protocols": {
		Table:        "emergency_protocols ep",
		IDColumn:     "ep.id",
		Select:       "ep.*",
		DefaultOrder: "ep.priority ASC, ep.title ASC",
		SearchColumns: []string{
			"ep.title", "coalesce(ep.description, '')", "ep.category",
		},
		FilterColumns: map[string]string{
			"status":   "ep.status",
			"category": "ep.category",
			"priority": "ep.priority",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("ep.deleted_at IS NULL").Where("ep.status = ?", "active")
		},
	},
	"faqs": {
		Table:        "faqs f",
		IDColumn:     "f.id",
		Select:       "f.*",
		DefaultOrder: "coalesce(f.sort_order, 999999), f.created_at DESC",
		SearchColumns: []string{
			"f.question", "f.answer", "coalesce(f.keywords, '')", "coalesce(f.target_audience, '')",
		},
		FilterColumns: map[string]string{
			"status":          "f.status",
			"priority":        "f.priority",
			"target_audience": "f.target_audience",
			"is_featured":     "f.is_featured::text",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("f.deleted_at IS NULL").Where("f.status = ?", "published")
		},
	},
	"documentation": {
		Table:        "documentation doc",
		IDColumn:     "doc.id",
		Select:       "doc.*",
		DefaultOrder: "doc.title ASC",
		SearchColumns: []string{
			"doc.title", "coalesce(doc.description, '')", "doc.content", "coalesce(doc.category, '')", "coalesce(doc.tags, '')",
		},
		FilterColumns: map[string]string{
			"status":   "doc.status",
			"category": "doc.category",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("doc.deleted_at IS NULL").Where("doc.status = ?", "published")
		},
	},
	"generic_pages": {
		Table:        "generic_pages gp",
		IDColumn:     "gp.id",
		Select:       "gp.*",
		DefaultOrder: "gp.title ASC",
		SearchColumns: []string{
			"gp.title", "coalesce(gp.description, '')", "gp.key",
		},
		FilterColumns: map[string]string{
			"key": "gp.key",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("gp.deleted_at IS NULL")
		},
	},
	"guideline_categories": {
		Table:        "guideline_categories gc",
		IDColumn:     "gc.id",
		Select:       "gc.*",
		DefaultOrder: "coalesce(gc.sort_order, 999999), gc.name ASC",
		SearchColumns: []string{
			"gc.name", "coalesce(gc.slug, '')", "coalesce(gc.description, '')",
		},
		FilterColumns: map[string]string{
			"status":             "gc.status",
			"parent_category_id": "gc.parent_category_id::text",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("gc.deleted_at IS NULL").Where("gc.status = ?", "active")
		},
	},
	"guideline_tags": {
		Table:        "guideline_tags gt",
		IDColumn:     "gt.id",
		Select:       "gt.*",
		DefaultOrder: "gt.name ASC",
		SearchColumns: []string{
			"gt.name", "coalesce(gt.description, '')",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("gt.deleted_at IS NULL")
		},
	},
	"drug_categories": {
		Table:        "drug_categories dc",
		IDColumn:     "dc.id",
		Select:       "dc.*",
		DefaultOrder: "coalesce(dc.sort_order, 999999), dc.name ASC",
		SearchColumns: []string{
			"dc.name", "coalesce(dc.slug, '')", "coalesce(dc.description, '')",
		},
		FilterColumns: map[string]string{
			"status":             "dc.status",
			"parent_category_id": "dc.parent_category_id::text",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("dc.deleted_at IS NULL").Where("dc.status = ?", "active")
		},
	},
	"drug_tags": {
		Table:        "drug_tags dt",
		IDColumn:     "dt.id",
		Select:       "dt.*",
		DefaultOrder: "dt.name ASC",
		SearchColumns: []string{
			"dt.name", "coalesce(dt.description, '')",
		},
		FilterColumns: map[string]string{
			"status": "dt.status",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("dt.deleted_at IS NULL").Where("dt.status = ?", "active")
		},
	},
	"drug_classes": {
		Table:        "drug_classes dc",
		IDColumn:     "dc.id",
		Select:       "dc.*",
		DefaultOrder: "dc.name ASC",
		SearchColumns: []string{
			"dc.name", "coalesce(dc.description, '')",
		},
		FilterColumns: map[string]string{
			"status": "dc.status",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("dc.deleted_at IS NULL").Where("dc.status = ?", "active")
		},
	},
	"therapeutic_categories": {
		Table:        "therapeutic_categories tc",
		IDColumn:     "tc.id",
		Select:       "tc.*",
		DefaultOrder: "tc.name ASC",
		SearchColumns: []string{
			"tc.name", "coalesce(tc.description, '')",
		},
		FilterColumns: map[string]string{
			"status": "tc.status",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("tc.deleted_at IS NULL").Where("tc.status = ?", "active")
		},
	},
	"consultants": {
		Table:        "consultants c",
		IDColumn:     "c.id",
		Select:       "c.*, u.id::text AS user_expand_id, u.name AS user_expand_name, u.email AS user_expand_email, u.avatar AS user_expand_avatar, u.verified AS user_expand_verified",
		DefaultOrder: "c.name ASC",
		SearchColumns: []string{
			"c.name", "c.email", "c.phone", "c.specialty", "coalesce(c.organization, '')", "coalesce(c.region, '')", "coalesce(c.city, '')",
		},
		FilterColumns: map[string]string{
			"status":      "c.status",
			"specialty":   "c.specialty",
			"region":      "c.region",
			"city":        "c.city",
			"is_verified": "c.is_verified::text",
		},
		Access: legacyAccessPublic,
		Joins:  []string{"LEFT JOIN users u ON u.id = c.user_id"},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("c.deleted_at IS NULL").Where("c.status = ?", "active")
		},
	},
	"health_facilities": {
		Table:        "health_facilities hf",
		IDColumn:     "hf.id",
		Select:       "hf.*, fl.name AS facility_level_name, a.name AS authority_name, ot.name AS ownership_type_name, d.name AS district_name, r.name AS region_name",
		DefaultOrder: "hf.name ASC",
		SearchColumns: []string{
			"hf.name", "hf.nhpi_code", "hf.hsdt_code", "coalesce(d.name, '')", "coalesce(r.name, '')",
		},
		FilterColumns: map[string]string{
			"region_id":         "hf.region_id::text",
			"district_id":       "hf.district_id::text",
			"facility_level_id": "hf.facility_level_id::text",
			"authority_id":      "hf.authority_id::text",
		},
		Access: legacyAccessPublic,
		Joins: []string{
			"LEFT JOIN facility_levels fl ON fl.id = hf.facility_level_id",
			"LEFT JOIN authorities a ON a.id = hf.authority_id",
			"LEFT JOIN ownership_types ot ON ot.id = hf.ownership_type_id",
			"LEFT JOIN districts d ON d.id = hf.district_id",
			"LEFT JOIN regions r ON r.id = hf.region_id",
		},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("hf.deleted_at IS NULL")
		},
	},
	"regions": {
		Table:        "regions r",
		IDColumn:     "r.id",
		Select:       "r.*",
		DefaultOrder: "r.name ASC",
		SearchColumns: []string{
			"r.name", "r.nhpi_code", "r.hsdt_code",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("r.deleted_at IS NULL")
		},
	},
	"districts": {
		Table:        "districts d",
		IDColumn:     "d.id",
		Select:       "d.*, r.name AS region_name",
		DefaultOrder: "d.name ASC",
		SearchColumns: []string{
			"d.name", "d.nhpi_code", "d.hsdt_code", "coalesce(r.name, '')",
		},
		FilterColumns: map[string]string{
			"region_id": "d.region_id::text",
		},
		Access: legacyAccessPublic,
		Joins:  []string{"LEFT JOIN regions r ON r.id = d.region_id"},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("d.deleted_at IS NULL")
		},
	},
	"counties": {
		Table:        "counties c",
		IDColumn:     "c.id",
		Select:       "c.*, d.name AS district_name",
		DefaultOrder: "c.name ASC",
		SearchColumns: []string{
			"c.name", "c.nhpi_code", "c.hsdt_code", "coalesce(d.name, '')",
		},
		FilterColumns: map[string]string{
			"district_id": "c.district_id::text",
		},
		Access: legacyAccessPublic,
		Joins:  []string{"LEFT JOIN districts d ON d.id = c.district_id"},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("c.deleted_at IS NULL")
		},
	},
	"subcounties": {
		Table:        "subcounties s",
		IDColumn:     "s.id",
		Select:       "s.*, d.name AS district_name, c.name AS county_name",
		DefaultOrder: "s.name ASC",
		SearchColumns: []string{
			"s.name", "s.nhpi_code", "s.hsdt_code", "coalesce(d.name, '')", "coalesce(c.name, '')",
		},
		FilterColumns: map[string]string{
			"district_id": "s.district_id::text",
			"county_id":   "s.county_id::text",
		},
		Access: legacyAccessPublic,
		Joins: []string{
			"LEFT JOIN districts d ON d.id = s.district_id",
			"LEFT JOIN counties c ON c.id = s.county_id",
		},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("s.deleted_at IS NULL")
		},
	},
	"parishes": {
		Table:        "parishes p",
		IDColumn:     "p.id",
		Select:       "p.*, s.name AS subcounty_name",
		DefaultOrder: "p.name ASC",
		SearchColumns: []string{
			"p.name", "p.nhpi_code", "p.hsdt_code", "coalesce(s.name, '')",
		},
		FilterColumns: map[string]string{
			"subcounty_id": "p.subcounty_id::text",
		},
		Access: legacyAccessPublic,
		Joins:  []string{"LEFT JOIN subcounties s ON s.id = p.subcounty_id"},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("p.deleted_at IS NULL")
		},
	},
	"facility_levels": {
		Table:        "facility_levels fl",
		IDColumn:     "fl.id",
		Select:       "fl.*",
		DefaultOrder: "fl.name ASC",
		SearchColumns: []string{
			"fl.code", "fl.name",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("fl.deleted_at IS NULL")
		},
	},
	"ownership_types": {
		Table:        "ownership_types ot",
		IDColumn:     "ot.id",
		Select:       "ot.*",
		DefaultOrder: "ot.name ASC",
		SearchColumns: []string{
			"ot.code", "ot.name",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("ot.deleted_at IS NULL")
		},
	},
	"authorities": {
		Table:        "authorities a",
		IDColumn:     "a.id",
		Select:       "a.*, ot.name AS ownership_type_name",
		DefaultOrder: "a.name ASC",
		SearchColumns: []string{
			"a.name", "coalesce(a.code, '')", "coalesce(ot.name, '')",
		},
		FilterColumns: map[string]string{
			"ownership_type_id": "a.ownership_type_id::text",
		},
		Access: legacyAccessPublic,
		Joins:  []string{"LEFT JOIN ownership_types ot ON ot.id = a.ownership_type_id"},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("a.deleted_at IS NULL")
		},
	},
	"ministry_directory": {
		Table:        "ministry_directory md",
		IDColumn:     "md.id",
		Select:       "md.*, d.name AS district_name, r.name AS region_name",
		DefaultOrder: "md.priority_level ASC, md.name ASC",
		SearchColumns: []string{
			"md.name", "md.title", "md.ministry", "coalesce(md.department, '')", "md.phone", "coalesce(md.email, '')",
		},
		FilterColumns: map[string]string{
			"status":      "md.status",
			"district_id": "md.district_id::text",
			"region_id":   "md.region_id::text",
			"ministry":    "md.ministry",
			"department":  "md.department",
		},
		Access: legacyAccessPublic,
		Joins: []string{
			"LEFT JOIN districts d ON d.id = md.district_id",
			"LEFT JOIN regions r ON r.id = md.region_id",
		},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("md.deleted_at IS NULL").Where("md.status = ?", "active")
		},
	},
	"languages": {
		Table:        "languages l",
		IDColumn:     "l.id",
		Select:       "l.*",
		DefaultOrder: "l.name ASC",
		SearchColumns: []string{
			"l.code", "l.name", "l.native_name",
		},
		FilterColumns: map[string]string{
			"status":     "l.status",
			"is_active":  "l.is_active::text",
			"is_default": "l.is_default::text",
		},
		Access: legacyAccessPublic,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("l.deleted_at IS NULL").Where("l.is_active = ?", true)
		},
	},
	"users": {
		Table:        "users u",
		IDColumn:     "u.id",
		Select:       "u.*",
		DefaultOrder: "u.updated_at DESC",
		SearchColumns: []string{
			"u.name", "u.email", "coalesce(u.phone, '')",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("u.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("u.id::text = ?", userID)
		},
	},
	"notifications": {
		Table:        "notifications n",
		IDColumn:     "n.id",
		Select:       "n.*",
		DefaultOrder: "n.created_at DESC",
		SearchColumns: []string{
			"n.title", "n.message", "n.type", "n.priority",
		},
		FilterColumns: map[string]string{
			"type":     "n.type",
			"priority": "n.priority",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("n.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("(n.user_id::text = ? OR n.user_id IS NULL)", userID)
		},
	},
	"notification_templates": {
		Table:        "notification_templates nt",
		IDColumn:     "nt.id",
		Select:       "nt.*",
		DefaultOrder: "nt.name ASC",
		SearchColumns: []string{
			"nt.name", "nt.type", "nt.category", "coalesce(nt.subject, '')",
		},
		FilterColumns: map[string]string{
			"status":   "nt.status",
			"type":     "nt.type",
			"category": "nt.category",
		},
		Access: legacyAccessAuth,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("nt.deleted_at IS NULL")
		},
	},
	"notification_campaigns": {
		Table:        "notification_campaigns nc",
		IDColumn:     "nc.id",
		Select:       "nc.*",
		DefaultOrder: "nc.created_at DESC",
		SearchColumns: []string{
			"nc.name", "nc.type", "nc.status",
		},
		FilterColumns: map[string]string{
			"status": "nc.status",
			"type":   "nc.type",
		},
		Access: legacyAccessAuth,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("nc.deleted_at IS NULL")
		},
	},
	"support_tickets": {
		Table:        "support_tickets st",
		IDColumn:     "st.id",
		Select:       "st.*",
		DefaultOrder: "st.updated_at DESC",
		SearchColumns: []string{
			"st.subject", "st.description", "coalesce(st.category, '')", "st.status", "st.priority",
		},
		FilterColumns: map[string]string{
			"status":   "st.status",
			"priority": "st.priority",
			"category": "st.category",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("st.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("(st.user_id::text = ? OR st.assigned_to::text = ?)", userID, userID)
		},
	},
	"support_ticket_replies": {
		Table:        "support_ticket_replies str",
		IDColumn:     "str.id",
		Select:       "str.*, u.id::text AS user_expand_id, u.name AS user_expand_name, u.email AS user_expand_email, u.avatar AS user_expand_avatar, u.verified AS user_expand_verified",
		DefaultOrder: "str.created_at ASC",
		SearchColumns: []string{
			"str.message",
		},
		FilterColumns: map[string]string{
			"ticket_id":   "str.ticket_id::text",
			"is_internal": "str.is_internal::text",
		},
		Access: legacyAccessUser,
		Joins:  []string{"LEFT JOIN support_tickets st ON st.id = str.ticket_id", "LEFT JOIN users u ON u.id = str.user_id"},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("str.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("(str.user_id::text = ? OR st.user_id::text = ? OR st.assigned_to::text = ?)", userID, userID, userID)
		},
	},
	"conversations": {
		Table:        "conversations c",
		IDColumn:     "c.id",
		Select:       "c.*, p1.id::text AS participant1_expand_id, p1.name AS participant1_expand_name, p1.email AS participant1_expand_email, p1.avatar AS participant1_expand_avatar, p1.verified AS participant1_expand_verified, p2.id::text AS participant2_expand_id, p2.name AS participant2_expand_name, p2.email AS participant2_expand_email, p2.avatar AS participant2_expand_avatar, p2.verified AS participant2_expand_verified, lm.id::text AS last_message_id, lm.content AS last_message",
		DefaultOrder: "c.updated_at DESC",
		FilterColumns: map[string]string{
			"participant1_user_id": "c.participant1_user_id::text",
			"participant2_user_id": "c.participant2_user_id::text",
		},
		Access: legacyAccessUser,
		Joins: []string{
			"LEFT JOIN users p1 ON p1.id = c.participant1_user_id",
			"LEFT JOIN users p2 ON p2.id = c.participant2_user_id",
			"LEFT JOIN LATERAL (SELECT id, content FROM messages WHERE conversation_id = c.id AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1) lm ON true",
		},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("c.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("(c.participant1_user_id::text = ? OR c.participant2_user_id::text = ?)", userID, userID)
		},
	},
	"messages": {
		Table:        "messages m",
		IDColumn:     "m.id",
		Select:       "m.*, u.id::text AS sender_expand_id, u.name AS sender_expand_name, u.email AS sender_expand_email, u.avatar AS sender_expand_avatar, u.verified AS sender_expand_verified",
		DefaultOrder: "m.created_at DESC",
		SearchColumns: []string{
			"m.content", "coalesce(m.message_type, '')",
		},
		FilterColumns: map[string]string{
			"conversation_id": "m.conversation_id::text",
			"sender_user_id":  "m.sender_user_id::text",
			"message_type":    "m.message_type",
		},
		Access: legacyAccessUser,
		Joins:  []string{"LEFT JOIN conversations c ON c.id = m.conversation_id", "LEFT JOIN users u ON u.id = m.sender_user_id"},
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("m.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("(c.participant1_user_id::text = ? OR c.participant2_user_id::text = ?)", userID, userID)
		},
	},
	"reading_progress": {
		Table:        "reading_progress rp",
		IDColumn:     "rp.id",
		Select:       "rp.*",
		DefaultOrder: "rp.updated_at DESC",
		FilterColumns: map[string]string{
			"guideline_document_id": "rp.guideline_document_id::text",
			"is_bookmarked":         "rp.is_bookmarked::text",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("rp.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("rp.user_id::text = ?", userID)
		},
	},
	"calculator_usage_logs": {
		Table:        "calculator_usage_logs cul",
		IDColumn:     "cul.id",
		Select:       "cul.*",
		DefaultOrder: "cul.created_at DESC",
		FilterColumns: map[string]string{
			"calculator_id":   "cul.calculator_id::text",
			"calculator_type": "cul.calculator_type",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("cul.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("cul.user_id::text = ?", userID)
		},
	},
	"guideline_usage_logs": {
		Table:        "guideline_usage_logs gul",
		IDColumn:     "gul.id",
		Select:       "gul.*",
		DefaultOrder: "gul.created_at DESC",
		FilterColumns: map[string]string{
			"guideline_document_id": "gul.guideline_document_id::text",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("gul.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("gul.user_id::text = ?", userID)
		},
	},
	"drug_usage_logs": {
		Table:        "drug_usage_logs dul",
		IDColumn:     "dul.id",
		Select:       "dul.*",
		DefaultOrder: "dul.created_at DESC",
		FilterColumns: map[string]string{
			"drug_id": "dul.drug_id::text",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("dul.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("dul.user_id::text = ?", userID)
		},
	},
	"abbreviation_usage_logs": {
		Table:        "abbreviation_usage_logs aul",
		IDColumn:     "aul.id",
		Select:       "aul.*",
		DefaultOrder: "aul.created_at DESC",
		FilterColumns: map[string]string{
			"abbreviation_id": "aul.abbreviation_id::text",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("aul.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("aul.user_id::text = ?", userID)
		},
	},
	"consultant_usage_logs": {
		Table:        "consultant_usage_logs cul",
		IDColumn:     "cul.id",
		Select:       "cul.*",
		DefaultOrder: "cul.created_at DESC",
		FilterColumns: map[string]string{
			"consultant_id": "cul.consultant_id::text",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("cul.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("cul.user_id::text = ?", userID)
		},
	},
	"facility_usage_logs": {
		Table:        "facility_usage_logs ful",
		IDColumn:     "ful.id",
		Select:       "ful.*",
		DefaultOrder: "ful.created_at DESC",
		FilterColumns: map[string]string{
			"facility_id": "ful.facility_id::text",
		},
		Access: legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("ful.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("ful.user_id::text = ?", userID)
		},
	},
	"ai_usage_logs": {
		Table:        "ai_usage_logs aiu",
		IDColumn:     "aiu.id",
		Select:       "aiu.*",
		DefaultOrder: "aiu.created_at DESC",
		Access:       legacyAccessUser,
		ApplyScopes: func(query *gorm.DB) *gorm.DB {
			return query.Where("aiu.deleted_at IS NULL")
		},
		ApplyUser: func(query *gorm.DB, userID string) *gorm.DB {
			return query.Where("aiu.user_id::text = ?", userID)
		},
	},
}

func (s LegacyCollectionService) SupportedCollections() []string {
	names := make([]string, 0, len(legacyCollectionSpecs))
	for name := range legacyCollectionSpecs {
		names = append(names, name)
	}
	return names
}

func LegacyCollectionErrorMessage(err error) string {
	switch {
	case errors.Is(err, ErrLegacyCollectionNotFound):
		return "collection not found"
	case errors.Is(err, ErrLegacyCollectionAuthNeeded):
		return "authentication required"
	case errors.Is(err, ErrLegacyCollectionForbidden):
		return "forbidden"
	case errors.Is(err, ErrLegacyCollectionWrite):
		return "write operation not supported"
	case errors.Is(err, ErrLegacyCollectionInvalid):
		return "invalid payload"
	case errors.Is(err, gorm.ErrRecordNotFound):
		return "record not found"
	default:
		return fmt.Sprintf("legacy collection error: %v", err)
	}
}
