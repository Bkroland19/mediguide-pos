import { cleanup, fireEvent, render, screen } from "@testing-library/react"
import Link from "next/link"
import { afterEach, describe, expect, it, vi } from "vitest"

import { useUnsavedChanges } from "./use-unsaved-changes"

function Harness({ dirty }: { dirty: boolean }) {
  useUnsavedChanges(dirty)
  return (
    <Link href="/guidelines" onClick={(event) => event.preventDefault()}>
      Leave editor
    </Link>
  )
}

describe("useUnsavedChanges", () => {
  afterEach(() => {
    cleanup()
    vi.restoreAllMocks()
  })

  it("warns before following a link with unsaved edits", () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false)
    render(<Harness dirty />)

    const allowed = fireEvent.click(screen.getByRole("link", { name: "Leave editor" }))

    expect(allowed).toBe(false)
    expect(confirm).toHaveBeenCalledOnce()
  })

  it("does not warn when content is clean", () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false)
    render(<Harness dirty={false} />)

    fireEvent.click(screen.getByRole("link", { name: "Leave editor" }))

    expect(confirm).not.toHaveBeenCalled()
  })
})
