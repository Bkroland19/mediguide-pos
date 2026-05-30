import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Progress } from "@/components/ui/progress"

export default function OnboardingPage() {
  return (
    <Card className="w-full max-w-2xl">
      <CardHeader className="space-y-1">
        <CardTitle className="text-2xl text-center">Welcome to MediGuide</CardTitle>
        <CardDescription className="text-center">
          Let&apos;s set up your administrator profile
        </CardDescription>
        <Progress value={33} className="w-full" />
        <p className="text-sm text-muted-foreground text-center">Step 1 of 3</p>
      </CardHeader>
      <CardContent className="space-y-6">
        <div className="space-y-4">
          <h3 className="text-lg font-medium">Personal Information</h3>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="firstName">First Name</Label>
              <Input id="firstName" placeholder="John" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="lastName">Last Name</Label>
              <Input id="lastName" placeholder="Doe" />
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="title">Job Title</Label>
            <Input id="title" placeholder="System Administrator" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="organization">Organization</Label>
            <Input id="organization" placeholder="Health Ministry" />
          </div>
        </div>

        <div className="space-y-4">
          <h3 className="text-lg font-medium">System Preferences</h3>
          <div className="space-y-2">
            <Label htmlFor="country">Country</Label>
            <Select>
              <SelectTrigger>
                <SelectValue placeholder="Select your country" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ke">Kenya</SelectItem>
                <SelectItem value="ug">Uganda</SelectItem>
                <SelectItem value="tz">Tanzania</SelectItem>
                <SelectItem value="rw">Rwanda</SelectItem>
                <SelectItem value="other">Other</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-2">
            <Label htmlFor="language">Preferred Language</Label>
            <Select>
              <SelectTrigger>
                <SelectValue placeholder="Select language" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="en">English</SelectItem>
                <SelectItem value="sw">Swahili</SelectItem>
                <SelectItem value="fr">French</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        <div className="flex justify-between">
          <Button variant="outline" disabled>
            Previous
          </Button>
          <Button>
            Next Step
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}