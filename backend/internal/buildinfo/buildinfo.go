package buildinfo

// Version and Revision are overridden with Go linker flags in release images.
var (
	Version  = "development"
	Revision = "unknown"
)
