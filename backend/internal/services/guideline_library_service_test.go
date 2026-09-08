package services

import (
	"errors"
	"strings"
	"testing"

	"mediguide/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func newGuidelineLibraryTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open("file:"+uuid.NewString()+"?mode=memory&cache=shared"), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.User{}, &models.GuidelineDocument{}, &models.GuidelineVersion{}, &models.GuidelineCollection{}, &models.GuidelineCollectionItem{}, &models.GuidelineDownload{}); err != nil {
		t.Fatal(err)
	}
	return db
}

func createGuidelineLibraryUser(t *testing.T, db *gorm.DB, email string) uuid.UUID {
	t.Helper()
	id := uuid.New()
	if err := db.Create(&models.User{Base: models.Base{ID: id}, Name: "Reader", Email: email, PasswordHash: "hash"}).Error; err != nil {
		t.Fatal(err)
	}
	return id
}

func createGuidelineLibraryDocument(t *testing.T, db *gorm.DB, status string) models.GuidelineDocument {
	t.Helper()
	document := models.GuidelineDocument{Title: "Care " + uuid.NewString()}
	if err := db.Create(&document).Error; err != nil {
		t.Fatal(err)
	}
	version := models.GuidelineVersion{DocumentID: document.ID, Version: "1", Status: status, OriginalFileKey: "source/care.pdf"}
	if err := db.Create(&version).Error; err != nil {
		t.Fatal(err)
	}
	document.CurrentVersionID = &version.ID
	if err := db.Save(&document).Error; err != nil {
		t.Fatal(err)
	}
	return document
}

func TestGuidelineLibraryScopesCollectionsAndDownloadsToOwner(t *testing.T) {
	db, err := gorm.Open(sqlite.Open("file:"+uuid.NewString()+"?mode=memory&cache=shared"), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.User{}, &models.GuidelineDocument{}, &models.GuidelineVersion{}, &models.GuidelineCollection{}, &models.GuidelineCollectionItem{}, &models.GuidelineDownload{}); err != nil {
		t.Fatal(err)
	}
	owner, other := uuid.New(), uuid.New()
	for id, email := range map[uuid.UUID]string{owner: "owner@example.test", other: "other@example.test"} {
		if err := db.Create(&models.User{Base: models.Base{ID: id}, Name: "Reader", Email: email, PasswordHash: "hash"}).Error; err != nil {
			t.Fatal(err)
		}
	}
	document := models.GuidelineDocument{Title: "Care"}
	if err := db.Create(&document).Error; err != nil {
		t.Fatal(err)
	}
	version := models.GuidelineVersion{DocumentID: document.ID, Version: "1", Status: "published", OriginalFileKey: "source/care.pdf"}
	if err := db.Create(&version).Error; err != nil {
		t.Fatal(err)
	}
	document.CurrentVersionID = &version.ID
	if err := db.Save(&document).Error; err != nil {
		t.Fatal(err)
	}

	service := GuidelineLibraryService{DB: db}
	collection, err := service.CreateCollection(owner, GuidelineCollectionInput{Name: "Ward round"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.GetCollection(other, collection.ID); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("other user read collection: %v", err)
	}
	if err := service.AddCollectionItem(other, collection.ID, GuidelineCollectionItemInput{GuidelineID: document.ID}); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("other user changed collection: %v", err)
	}
	if err := service.AddCollectionItem(owner, collection.ID, GuidelineCollectionItemInput{GuidelineID: document.ID}); err != nil {
		t.Fatal(err)
	}
	collectionItems, err := service.ListCollectionItems(owner, collection.ID, PageInput{})
	if err != nil || collectionItems.TotalItems != 1 || collectionItems.Items[0].Guideline.ID != document.ID {
		t.Fatalf("unexpected collection items: %#v %v", collectionItems, err)
	}
	owned, err := service.GetCollection(owner, collection.ID)
	if err != nil || owned.ItemCount != 1 {
		t.Fatalf("unexpected owned collection: %#v %v", owned, err)
	}
	if _, err := service.RecordDownload(owner, GuidelineDownloadInput{GuidelineID: document.ID, AssetType: string(models.GuidelineAssetOriginalPDF)}); err != nil {
		t.Fatal(err)
	}
	ownerDownloads, err := service.ListDownloads(owner, PageInput{}, "", "", "")
	if err != nil || ownerDownloads.TotalItems != 1 {
		t.Fatalf("missing owner download: %#v %v", ownerDownloads, err)
	}
	otherDownloads, err := service.ListDownloads(other, PageInput{}, "", "", "")
	if err != nil || otherDownloads.TotalItems != 0 {
		t.Fatalf("download leaked to other user: %#v %v", otherDownloads, err)
	}
}

func TestGuidelineLibraryCollectionLifecycleValidationAndConflicts(t *testing.T) {
	db := newGuidelineLibraryTestDB(t)
	owner := createGuidelineLibraryUser(t, db, "collection-owner@example.test")
	other := createGuidelineLibraryUser(t, db, "collection-other@example.test")
	service := GuidelineLibraryService{DB: db}

	ward, err := service.CreateCollection(owner, GuidelineCollectionInput{Name: "  Ward round  ", Description: "  Daily care  "})
	if err != nil || ward.Name != "Ward round" || ward.Description != "Daily care" {
		t.Fatalf("unexpected created collection: %#v %v", ward, err)
	}
	if _, err := service.CreateCollection(owner, GuidelineCollectionInput{Name: "ward ROUND"}); !errors.Is(err, ErrGuidelineLibraryConflict) {
		t.Fatalf("duplicate collection was not a conflict: %v", err)
	}
	clinic, err := service.CreateCollection(owner, GuidelineCollectionInput{Name: "Clinic"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.UpdateCollection(owner, clinic.ID, GuidelineCollectionInput{Name: "WARD ROUND"}); !errors.Is(err, ErrGuidelineLibraryConflict) {
		t.Fatalf("duplicate rename was not a conflict: %v", err)
	}
	updated, err := service.UpdateCollection(owner, ward.ID, GuidelineCollectionInput{Name: "Ward team", Description: "Shared rounds"})
	if err != nil || updated.Name != "Ward team" || updated.Description != "Shared rounds" {
		t.Fatalf("unexpected updated collection: %#v %v", updated, err)
	}
	if _, err := service.UpdateCollection(other, ward.ID, GuidelineCollectionInput{Name: "Stolen"}); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("other user updated collection: %v", err)
	}
	if err := service.DeleteCollection(other, ward.ID); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("other user deleted collection: %v", err)
	}
	if err := service.DeleteCollection(owner, ward.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := service.GetCollection(owner, ward.ID); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("deleted collection remained visible: %v", err)
	}

	if _, err := service.CreateCollection(owner, GuidelineCollectionInput{Name: strings.Repeat("界", 120)}); err != nil {
		t.Fatalf("120-character unicode name rejected: %v", err)
	}
	for name, description := range map[string]string{
		"":                       "",
		strings.Repeat("界", 121): "",
		"Description too long":   strings.Repeat("界", 1001),
	} {
		if _, err := service.CreateCollection(owner, GuidelineCollectionInput{Name: name, Description: description}); !errors.Is(err, ErrGuidelineLibraryInvalid) {
			t.Fatalf("invalid collection accepted (name length %d, description length %d): %v", len([]rune(name)), len([]rune(description)), err)
		}
	}
}

func TestGuidelineLibraryCollectionItemsAreIdempotentRestorableAndPublished(t *testing.T) {
	db := newGuidelineLibraryTestDB(t)
	owner := createGuidelineLibraryUser(t, db, "items-owner@example.test")
	other := createGuidelineLibraryUser(t, db, "items-other@example.test")
	published := createGuidelineLibraryDocument(t, db, "published")
	unpublished := createGuidelineLibraryDocument(t, db, "draft")
	service := GuidelineLibraryService{DB: db}
	collection, err := service.CreateCollection(owner, GuidelineCollectionInput{Name: "Rounds"})
	if err != nil {
		t.Fatal(err)
	}

	if err := service.AddCollectionItem(owner, collection.ID, GuidelineCollectionItemInput{GuidelineID: unpublished.ID}); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("unpublished guideline was accepted: %v", err)
	}
	for range 2 {
		if err := service.AddCollectionItem(owner, collection.ID, GuidelineCollectionItemInput{GuidelineID: published.ID, SortOrder: 3}); err != nil {
			t.Fatal(err)
		}
	}
	items, err := service.ListCollectionItems(owner, collection.ID, PageInput{})
	if err != nil || items.TotalItems != 1 || items.Items[0].SortOrder != 3 {
		t.Fatalf("duplicate add was not idempotent: %#v %v", items, err)
	}
	if err := service.RemoveCollectionItem(other, collection.ID, published.ID); !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("other user removed collection item: %v", err)
	}
	if err := service.RemoveCollectionItem(owner, collection.ID, published.ID); err != nil {
		t.Fatal(err)
	}
	if err := service.AddCollectionItem(owner, collection.ID, GuidelineCollectionItemInput{GuidelineID: published.ID, SortOrder: 1}); err != nil {
		t.Fatalf("soft-deleted item was not restored: %v", err)
	}
	items, err = service.ListCollectionItems(owner, collection.ID, PageInput{})
	if err != nil || items.TotalItems != 1 || items.Items[0].SortOrder != 1 {
		t.Fatalf("unexpected restored items: %#v %v", items, err)
	}
	refreshed, err := service.GetCollection(owner, collection.ID)
	if err != nil || refreshed.ItemCount != 1 {
		t.Fatalf("unexpected item count: %#v %v", refreshed, err)
	}
}

func TestGuidelineLibraryCollectionPaginationAndSorting(t *testing.T) {
	db := newGuidelineLibraryTestDB(t)
	owner := createGuidelineLibraryUser(t, db, "pagination@example.test")
	service := GuidelineLibraryService{DB: db}
	for _, name := range []string{"Zulu", "Alpha", "Mike"} {
		if _, err := service.CreateCollection(owner, GuidelineCollectionInput{Name: name}); err != nil {
			t.Fatal(err)
		}
	}
	page, err := service.ListCollections(owner, PageInput{Page: 1, PerPage: 2}, "name", "asc")
	if err != nil || page.TotalItems != 3 || page.TotalPages != 2 || len(page.Items) != 2 || page.Items[0].Name != "Alpha" || page.Items[1].Name != "Mike" {
		t.Fatalf("unexpected sorted page: %#v %v", page, err)
	}
	if _, err := service.ListCollections(owner, PageInput{}, "unsafe", "asc"); !errors.Is(err, ErrGuidelineLibraryInvalid) {
		t.Fatalf("unsafe sort was accepted: %v", err)
	}
}

func TestGuidelineLibraryWriteErrorNormalizesCollectionUniqueViolation(t *testing.T) {
	err := &pgconn.PgError{Code: "23505", ConstraintName: "uq_guideline_collections_user_name"}
	if !errors.Is(guidelineLibraryWriteError(err), ErrGuidelineLibraryConflict) {
		t.Fatal("collection unique violation was not normalized")
	}
	other := &pgconn.PgError{Code: "23505", ConstraintName: "some_other_constraint"}
	if guidelineLibraryWriteError(other) != other {
		t.Fatal("unrelated unique violation was incorrectly normalized")
	}
}
