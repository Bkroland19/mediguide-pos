"use client"

import { useEffect } from "react"
import { createPB } from "@/lib/pocketbase"

export function PocketBaseInit() {
  useEffect(() => {
    // Initialize PocketBase on client side only
    createPB()
  }, [])

  return null
}