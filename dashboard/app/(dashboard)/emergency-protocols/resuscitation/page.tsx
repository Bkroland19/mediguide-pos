'use client'

import * as React from "react"
import { useRouter } from "next/navigation"
import { usePermissionContext } from "@/lib/permission-context"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Label } from "@/components/ui/label"
import { PageHeader } from "@/components/ui/page-header"
import { 
  Heart,
  Clock,
  AlertTriangle,
  Zap,
  Activity,
  Users,
  FileText,
  Download
} from "lucide-react"

const resuscitationProtocols = {
  adult: {
    title: "Adult Basic Life Support (BLS)",
    steps: [
      {
        step: 1,
        title: "Check Responsiveness",
        description: "Tap shoulders firmly and shout 'Are you okay?'",
        duration: "5-10 seconds",
        critical: true
      },
      {
        step: 2,
        title: "Call for Help",
        description: "Call emergency services and request AED if available",
        duration: "Immediate",
        critical: true
      },
      {
        step: 3,
        title: "Check Pulse",
        description: "Check carotid pulse for no more than 10 seconds",
        duration: "≤10 seconds",
        critical: true
      },
      {
        step: 4,
        title: "Position Patient",
        description: "Place on firm, flat surface. Tilt head back, lift chin",
        duration: "5 seconds",
        critical: false
      },
      {
        step: 5,
        title: "Hand Placement",
        description: "Heel of hand on lower half of breastbone, between nipples",
        duration: "2-3 seconds",
        critical: true
      },
      {
        step: 6,
        title: "Chest Compressions",
        description: "Push hard and fast, at least 2 inches deep, 100-120/min",
        duration: "Continuous",
        critical: true
      },
      {
        step: 7,
        title: "Rescue Breaths",
        description: "30 compressions : 2 breaths ratio",
        duration: "1 second per breath",
        critical: true
      }
    ]
  },
  pediatric: {
    title: "Pediatric Basic Life Support",
    ageGroups: [
      {
        group: "Infant (&lt; 1 year)",
        compressions: "2 fingers, 1.5 inches deep",
        rate: "100-120/min",
        ratio: "30:2 (single rescuer), 15:2 (two rescuer)"
      },
      {
        group: "Child (1-8 years)",
        compressions: "1 or 2 hands, 2 inches deep",
        rate: "100-120/min",
        ratio: "30:2 (single rescuer), 15:2 (two rescuer)"
      }
    ]
  },
  medications: [
    {
      drug: "Epinephrine",
      dose: "1mg (1:10,000) IV/IO every 3-5 minutes",
      indication: "Cardiac arrest, all rhythms",
      notes: "Continue until ROSC or termination"
    },
    {
      drug: "Amiodarone",
      dose: "300mg IV/IO first dose, then 150mg",
      indication: "VF/VT refractory to defibrillation",
      notes: "Alternative to lidocaine"
    },
    {
      drug: "Atropine",
      dose: "0.5-1mg IV/IO every 3-5 minutes",
      indication: "Symptomatic bradycardia",
      notes: "Maximum total dose 3mg"
    }
  ],
  equipment: [
    { item: "AED/Defibrillator", priority: "Critical", status: "Available" },
    { item: "Bag-Mask Ventilation", priority: "Critical", status: "Available" },
    { item: "IV Access Supplies", priority: "High", status: "Available" },
    { item: "Emergency Medications", priority: "High", status: "Available" },
    { item: "Airway Management Kit", priority: "High", status: "Limited" },
    { item: "Cardiac Monitor", priority: "Medium", status: "Available" }
  ]
}

function getPriorityColor(priority: string) {
  switch (priority) {
    case 'Critical':
      return 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300'
    case 'High':
      return 'bg-orange-100 text-orange-800 dark:bg-orange-950 dark:text-orange-300'
    case 'Medium':
      return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-950 dark:text-yellow-300'
    default:
      return 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300'
  }
}

function getStatusColor(status: string) {
  switch (status) {
    case 'Available':
      return 'bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-300'
    case 'Limited':
      return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-950 dark:text-yellow-300'
    case 'Unavailable':
      return 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300'
    default:
      return 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300'
  }
}

export default function ResuscitationProtocolsPage() {
  const handlePrint = () => {
    window.print()
  }

  const handleDownloadPdf = () => {
    const previousTitle = document.title
    document.title = `Resuscitation Protocols - ${new Date().toISOString().slice(0, 10)}`
    const restore = () => {
      document.title = previousTitle
      window.removeEventListener("afterprint", restore)
    }
    window.addEventListener("afterprint", restore)
    window.print()
  }
  const router = useRouter()
  const { hasPermission, loading } = usePermissionContext()

  React.useEffect(() => {
    if (loading) return
    if (!hasPermission("content", "read:any")) {
      router.replace("/emergency-protocols")
    }
  }, [loading, hasPermission, router])

  return (
    <div className="space-y-6">
      <PageHeader
        title="Resuscitation Protocols"
        description="Evidence-based cardiac and respiratory resuscitation guidelines"
        actions={[
          {
            label: "Download PDF",
            variant: "outline",
            icon: <Download className="h-4 w-4" />,
            onClick: handleDownloadPdf,
          },
          {
            label: "Print Protocol",
            icon: <FileText className="h-4 w-4" />,
            onClick: handlePrint,
          },
        ]}
      />

      {/* Critical Reminders */}
      <Alert>
        <AlertTriangle className="h-4 w-4" />
        <AlertDescription>
          <strong>Remember:</strong> High-quality CPR with minimal interruptions. Push hard, push fast, allow complete chest recoil, and minimize interruptions.
        </AlertDescription>
      </Alert>

      <Tabs defaultValue="adult" className="space-y-4">
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="adult">Adult BLS</TabsTrigger>
          <TabsTrigger value="pediatric">Pediatric BLS</TabsTrigger>
          <TabsTrigger value="medications">Medications</TabsTrigger>
          <TabsTrigger value="equipment">Equipment</TabsTrigger>
        </TabsList>

        <TabsContent value="adult">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center space-x-2">
                <Heart className="h-5 w-5 text-red-500" />
                <span>{resuscitationProtocols.adult.title}</span>
              </CardTitle>
              <CardDescription>
                Step-by-step protocol for adult cardiac arrest
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {resuscitationProtocols.adult.steps.map((step) => (
                  <div key={step.step} className={`p-4 border rounded-lg ${step.critical ? 'border-red-200 bg-red-50 dark:border-red-900 dark:bg-red-950/40' : 'border-border bg-card'}`}>
                    <div className="flex items-start justify-between">
                      <div className="flex items-start space-x-4">
                        <div className={`flex items-center justify-center w-8 h-8 rounded-full text-white font-bold ${
                          step.critical ? 'bg-red-500' : 'bg-blue-500'
                        }`}>
                          {step.step}
                        </div>
                        <div className="flex-1">
                          <h4 className="font-semibold flex items-center space-x-2">
                            <span>{step.title}</span>
                            {step.critical && (
                              <Badge variant="destructive">Critical</Badge>
                            )}
                          </h4>
                          <p className="text-sm text-muted-foreground mt-1">
                            {step.description}
                          </p>
                        </div>
                      </div>
                      <div className="flex items-center space-x-1 text-sm text-muted-foreground">
                        <Clock className="h-3 w-3" />
                        <span>{step.duration}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
              
              <Alert className="mt-6">
                <Activity className="h-4 w-4" />
                <AlertDescription>
                  <strong>Quality Indicators:</strong> Compression depth 2-2.4 inches, rate 100-120/min, complete chest recoil, minimal interruptions (&lt;10 seconds).
                </AlertDescription>
              </Alert>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="pediatric">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center space-x-2">
                <Users className="h-5 w-5 text-blue-500" />
                <span>{resuscitationProtocols.pediatric.title}</span>
              </CardTitle>
              <CardDescription>
                Age-specific resuscitation protocols for children
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-6">
                {resuscitationProtocols.pediatric.ageGroups.map((group, index) => (
                  <div key={index} className="p-4 border rounded-lg border-border bg-card">
                    <h4 className="font-semibold text-lg mb-4">{group.group}</h4>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      <div>
                        <Label className="text-sm font-medium text-muted-foreground">Compression Technique</Label>
                        <p className="font-medium">{group.compressions}</p>
                      </div>
                      <div>
                        <Label className="text-sm font-medium text-muted-foreground">Rate</Label>
                        <p className="font-medium">{group.rate}</p>
                      </div>
                      <div>
                        <Label className="text-sm font-medium text-muted-foreground">Compression:Ventilation Ratio</Label>
                        <p className="font-medium">{group.ratio}</p>
                      </div>
                    </div>
                  </div>
                ))}
                
                <Alert>
                  <AlertTriangle className="h-4 w-4" />
                  <AlertDescription>
                    <strong>Pediatric Considerations:</strong> Airway obstruction is more common. Consider foreign body removal. Use appropriate equipment sizes.
                  </AlertDescription>
                </Alert>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="medications">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center space-x-2">
                <Zap className="h-5 w-5 text-yellow-500" />
                <span>Emergency Medications</span>
              </CardTitle>
              <CardDescription>
                Commonly used drugs in cardiac arrest scenarios
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {resuscitationProtocols.medications.map((med, index) => (
                  <div key={index} className="p-4 border rounded-lg border-border bg-card">
                    <div className="flex items-start justify-between mb-2">
                      <h4 className="font-semibold text-lg">{med.drug}</h4>
                      <Badge variant="outline">{med.indication}</Badge>
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <Label className="text-sm font-medium text-muted-foreground">Dose</Label>
                        <p className="font-medium">{med.dose}</p>
                      </div>
                      <div>
                        <Label className="text-sm font-medium text-muted-foreground">Notes</Label>
                        <p className="text-sm">{med.notes}</p>
                      </div>
                    </div>
                  </div>
                ))}
                
                <Alert>
                  <AlertTriangle className="h-4 w-4" />
                  <AlertDescription>
                    Always verify drug dosages and check for allergies before administration. Follow local protocols for drug availability and administration routes.
                  </AlertDescription>
                </Alert>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="equipment">
          <Card>
            <CardHeader>
              <CardTitle>Emergency Equipment Checklist</CardTitle>
              <CardDescription>
                Critical equipment for resuscitation procedures
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {resuscitationProtocols.equipment.map((item, index) => (
                  <div key={index} className="flex items-center justify-between p-3 border rounded-lg border-border bg-card">
                    <div className="flex items-center space-x-3">
                      <div className="w-2 h-2 rounded-full bg-gray-300"></div>
                      <span className="font-medium">{item.item}</span>
                    </div>
                    <div className="flex items-center space-x-2">
                      <Badge className={getPriorityColor(item.priority)}>
                        {item.priority}
                      </Badge>
                      <Badge className={getStatusColor(item.status)}>
                        {item.status}
                      </Badge>
                    </div>
                  </div>
                ))}
                
                <Alert>
                  <AlertTriangle className="h-4 w-4" />
                  <AlertDescription>
                    Ensure all critical equipment is readily available and functioning. Regular equipment checks should be performed and documented.
                  </AlertDescription>
                </Alert>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}
