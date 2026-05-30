"use client"

import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  XAxis,
  YAxis,
} from "recharts"
import {
  ChartContainer,
  ChartLegend,
  ChartLegendContent,
  ChartTooltip,
  ChartTooltipContent,
} from "@/components/ui/chart"
import { ChartCard } from "@/components/dashboard/chart-card"
import type { OverviewData } from "@/types/overview"

type SeriesProps = {
  users: OverviewData["series"]["usersByDay"]
  drugs: OverviewData["series"]["drugsByDay"]
  facilities: OverviewData["series"]["facilitiesByDay"]
}

export function OverviewSeriesChart({ users, drugs, facilities }: SeriesProps) {
  const data = users.map((item, index) => ({
    day: item.day,
    users: item.total,
    drugs: drugs[index]?.total ?? 0,
    facilities: facilities[index]?.total ?? 0,
  }))

  return (
    <ChartCard title="30-Day Activity">
        <ChartContainer
          className="h-[260px] w-full"
          config={{
            users: { label: "Users", color: "var(--chart-1)" },
            drugs: { label: "Drugs", color: "var(--chart-2)" },
            facilities: { label: "Facilities", color: "var(--chart-3)" },
          }}
        >
          <LineChart data={data} margin={{ left: 8, right: 16, top: 8 }}>
            <CartesianGrid vertical={false} />
            <XAxis
              dataKey="day"
              tickLine={false}
              axisLine={false}
              tickMargin={8}
              minTickGap={20}
              tickFormatter={(value: string) => value.slice(5)}
            />
            <YAxis tickLine={false} axisLine={false} tickMargin={8} />
            <ChartTooltip
              cursor={false}
              content={<ChartTooltipContent indicator="line" />}
            />
            <ChartLegend content={<ChartLegendContent />} />
            <Line
              type="monotone"
              dataKey="users"
              stroke="var(--color-users)"
              strokeWidth={2}
              dot={false}
            />
            <Line
              type="monotone"
              dataKey="drugs"
              stroke="var(--color-drugs)"
              strokeWidth={2}
              dot={false}
            />
            <Line
              type="monotone"
              dataKey="facilities"
              stroke="var(--color-facilities)"
              strokeWidth={2}
              dot={false}
            />
          </LineChart>
        </ChartContainer>
    </ChartCard>
  )
}

type EngagementProps = {
  engagement: OverviewData["engagement"]
}

export function OverviewEngagementChart({ engagement }: EngagementProps) {
  const data = [
    {
      name: "AI",
      last7: engagement.aiUsage7d,
      last30: engagement.aiUsage30d,
    },
    {
      name: "Calculators",
      last7: engagement.calculatorUsage7d,
      last30: engagement.calculatorUsage30d,
    },
    {
      name: "Guidelines",
      last7: engagement.guidelineUsage7d,
      last30: engagement.guidelineUsage30d,
    },
    {
      name: "Drugs",
      last7: engagement.drugUsage7d,
      last30: engagement.drugUsage30d,
    },
    {
      name: "Facilities",
      last7: engagement.facilityUsage7d,
      last30: engagement.facilityUsage30d,
    },
  ]

  return (
    <ChartCard title="Engagement (7d vs 30d)">
        <ChartContainer
          className="h-[260px] w-full"
          config={{
            last7: { label: "Last 7 days", color: "var(--chart-4)" },
            last30: { label: "Last 30 days", color: "var(--chart-5)" },
          }}
        >
          <BarChart data={data} margin={{ left: 8, right: 16, top: 8 }}>
            <CartesianGrid vertical={false} />
            <XAxis
              dataKey="name"
              tickLine={false}
              axisLine={false}
              tickMargin={8}
            />
            <YAxis tickLine={false} axisLine={false} tickMargin={8} />
            <ChartTooltip
              cursor={false}
              content={<ChartTooltipContent indicator="dashed" />}
            />
            <ChartLegend content={<ChartLegendContent />} />
            <Bar dataKey="last7" fill="var(--color-last7)" radius={[6, 6, 0, 0]} />
            <Bar dataKey="last30" fill="var(--color-last30)" radius={[6, 6, 0, 0]} />
          </BarChart>
        </ChartContainer>
    </ChartCard>
  )
}
