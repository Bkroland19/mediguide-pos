"use client"

import * as React from "react"
import { Users, Shield, Activity, TrendingUp } from "lucide-react"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { cn } from "@/lib/utils"

export interface StatCardData {
  title: string
  value: string | number
  description?: string
  icon?: React.ComponentType<{ className?: string }>
  trend?: {
    value: number
    label: string
    isPositive: boolean
  }
  className?: string
}

interface StatsCardsProps {
  cards: StatCardData[]
  loading?: boolean
  className?: string
}

export function StatsCards({ cards, loading = false, className }: StatsCardsProps) {
  if (loading) {
    return (
      <div className={cn("grid gap-4 md:grid-cols-2 lg:grid-cols-4", className)}>
        {Array.from({ length: 4 }).map((_, index) => (
          <Card key={index}>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <Skeleton className="h-4 w-[100px]" />
              <Skeleton className="h-4 w-4" />
            </CardHeader>
            <CardContent>
              <Skeleton className="h-7 w-[60px] mb-1" />
              <Skeleton className="h-3 w-[120px]" />
            </CardContent>
          </Card>
        ))}
      </div>
    )
  }

  return (
    <div className={cn("grid gap-4 md:grid-cols-2 lg:grid-cols-4", className)}>
      {cards.map((card, index) => (
        <Card key={index} className={card.className}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              {card.title}
            </CardTitle>
            {card.icon && (
              <card.icon className="h-4 w-4 text-muted-foreground" />
            )}
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{card.value}</div>
            {(card.description || card.trend) && (
              <div className="flex items-center pt-1">
                {card.trend && (
                  <div className="flex items-center text-xs text-muted-foreground">
                    <TrendingUp 
                      className={cn(
                        "mr-1 h-3 w-3",
                        card.trend.isPositive ? "text-green-500" : "text-red-500"
                      )} 
                    />
                    <span className={cn(
                      "font-medium",
                      card.trend.isPositive ? "text-green-600" : "text-red-600"
                    )}>
                      {card.trend.isPositive ? "+" : ""}{card.trend.value}%
                    </span>
                    <span className="ml-1">{card.trend.label}</span>
                  </div>
                )}
                {card.description && !card.trend && (
                  <p className="text-xs text-muted-foreground">
                    {card.description}
                  </p>
                )}
              </div>
            )}
          </CardContent>
        </Card>
      ))}
    </div>
  )
}

// Pre-built stat card configurations for common use cases
export const createRoleStatsCards = (stats: {
  totalRoles: number
  activeRoles: number
  totalUsers: number
  mostAssignedRole: { name: string; count: number } | null
}): StatCardData[] => [
  {
    title: "Total Roles",
    value: stats.totalRoles,
    description: "System roles available",
    icon: Shield,
  },
  {
    title: "Active Roles",
    value: stats.activeRoles,
    description: "Currently active roles",
    icon: Activity,
  },
  {
    title: "Total Users",
    value: stats.totalUsers,
    description: "Users in system",
    icon: Users,
  },
  {
    title: "Most Assigned Role",
    value: stats.mostAssignedRole?.name || "N/A",
    description: stats.mostAssignedRole ? `${stats.mostAssignedRole.count} users` : "No data",
    icon: TrendingUp,
  },
]

// Single stat card for standalone use
interface StatCardProps extends StatCardData {
  loading?: boolean
}

export function StatCard({ 
  title, 
  value, 
  description, 
  icon: Icon, 
  trend, 
  className,
  loading = false 
}: StatCardProps) {
  if (loading) {
    return (
      <Card className={className}>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <Skeleton className="h-4 w-[100px]" />
          <Skeleton className="h-4 w-4" />
        </CardHeader>
        <CardContent>
          <Skeleton className="h-7 w-[60px] mb-1" />
          <Skeleton className="h-3 w-[120px]" />
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className={className}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">
          {title}
        </CardTitle>
        {Icon && <Icon className="h-4 w-4 text-muted-foreground" />}
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        {(description || trend) && (
          <div className="flex items-center pt-1">
            {trend && (
              <div className="flex items-center text-xs text-muted-foreground">
                <TrendingUp 
                  className={cn(
                    "mr-1 h-3 w-3",
                    trend.isPositive ? "text-green-500" : "text-red-500"
                  )} 
                />
                <span className={cn(
                  "font-medium",
                  trend.isPositive ? "text-green-600" : "text-red-600"
                )}>
                  {trend.isPositive ? "+" : ""}{trend.value}%
                </span>
                <span className="ml-1">{trend.label}</span>
              </div>
            )}
            {description && !trend && (
              <p className="text-xs text-muted-foreground">
                {description}
              </p>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  )
}