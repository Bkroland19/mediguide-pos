"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import type { LucideIcon } from "lucide-react"

type StatCardProps = {
  title: string
  value: string | number
  helper?: string
  icon?: LucideIcon
  iconTone?: string
}

export function StatCard({
  title,
  value,
  helper,
  icon: Icon,
  iconTone = "text-muted-foreground",
}: StatCardProps) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{title}</CardTitle>
        {Icon ? <Icon className={`h-4 w-4 ${iconTone}`} /> : null}
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">
          {typeof value === "number" ? value.toLocaleString() : value}
        </div>
        {helper ? <p className="text-xs text-muted-foreground">{helper}</p> : null}
      </CardContent>
    </Card>
  )
}
