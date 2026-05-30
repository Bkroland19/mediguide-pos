import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"

interface PageTemplateProps {
  title: string
  description: string
  icon?: React.ComponentType<{ className?: string }>
  children?: React.ReactNode
}

export function PageTemplate({ title, description, icon: Icon, children }: PageTemplateProps) {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          {Icon && <Icon className="h-8 w-8 text-muted-foreground" />}
          <div>
            <h1 className="text-3xl font-bold tracking-tight">{title}</h1>
            <p className="text-muted-foreground">{description}</p>
          </div>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Coming Soon</CardTitle>
          <CardDescription>
            This page is under development and will be available soon.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-center h-32 text-muted-foreground">
            <div className="text-center">
              <p className="text-lg font-medium">Page Under Construction</p>
              <p className="text-sm">Full functionality will be implemented in the next phase</p>
            </div>
          </div>
          {children}
        </CardContent>
      </Card>
    </div>
  )
}