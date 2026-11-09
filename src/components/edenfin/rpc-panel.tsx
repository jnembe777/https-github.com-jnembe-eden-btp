/**
 * RPCPanel - Panneau d'exécution de fonctions RPC Supabase
 * Permet d'appeler des fonctions PostgreSQL avec interface graphique
 */

import { useState } from "react";
import { Play, Loader2, CheckCircle, XCircle, Code, Eye } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { useToast } from "@/hooks/use-toast";

export interface RPCParameter {
  name: string;
  type: "number" | "text" | "boolean" | "date" | "json";
  label: string;
  description?: string;
  defaultValue?: any;
  required?: boolean;
}

export interface RPCFunction {
  name: string;
  label: string;
  description: string;
  parameters: RPCParameter[];
  category?: string;
  icon?: React.ReactNode;
}

export interface RPCPanelProps {
  /** Fonction RPC à exécuter */
  rpcFunction: RPCFunction;
  /** Callback d'exécution */
  onExecute: (params: Record<string, any>) => Promise<any>;
  /** Afficher les résultats */
  showResults?: boolean;
  /** Afficher le code SQL généré */
  showSQL?: boolean;
}

export function RPCPanel({
  rpcFunction,
  onExecute,
  showResults = true,
  showSQL = false,
}: RPCPanelProps) {
  const [params, setParams] = useState<Record<string, any>>({});
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const { toast } = useToast();

  const handleExecute = async () => {
    try {
      setLoading(true);
      setError(null);

      const result = await onExecute(params);

      setResult(result);
      toast({
        title: "Exécution réussie",
        description: `La fonction ${rpcFunction.label} a été exécutée avec succès.`,
      });
    } catch (err: any) {
      const errorMessage = err.message || "Erreur lors de l'exécution";
      setError(errorMessage);
      toast({
        title: "Erreur",
        description: errorMessage,
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleParamChange = (paramName: string, value: any) => {
    setParams((prev) => ({
      ...prev,
      [paramName]: value,
    }));
  };

  const isValid = rpcFunction.parameters
    .filter((p) => p.required)
    .every((p) => params[p.name] !== undefined && params[p.name] !== "");

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <div>
            <CardTitle className="flex items-center gap-2">
              {rpcFunction.icon}
              {rpcFunction.label}
              {rpcFunction.category && (
                <Badge variant="outline">{rpcFunction.category}</Badge>
              )}
            </CardTitle>
            <CardDescription className="mt-1">
              {rpcFunction.description}
            </CardDescription>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <Tabs defaultValue="parameters" className="w-full">
          <TabsList className="grid w-full grid-cols-3">
            <TabsTrigger value="parameters">Paramètres</TabsTrigger>
            <TabsTrigger value="results" disabled={!result && !error}>
              Résultats
            </TabsTrigger>
            <TabsTrigger value="sql" disabled={!showSQL}>
              SQL
            </TabsTrigger>
          </TabsList>

          {/* Onglet Paramètres */}
          <TabsContent value="parameters" className="space-y-4">
            {rpcFunction.parameters.length === 0 ? (
              <div className="py-8 text-center text-sm text-muted-foreground">
                Cette fonction ne nécessite aucun paramètre
              </div>
            ) : (
              <div className="space-y-4">
                {rpcFunction.parameters.map((param) => (
                  <div key={param.name} className="space-y-2">
                    <Label htmlFor={param.name}>
                      {param.label}
                      {param.required && (
                        <span className="ml-1 text-destructive">*</span>
                      )}
                    </Label>
                    {param.description && (
                      <p className="text-xs text-muted-foreground">
                        {param.description}
                      </p>
                    )}
                    {param.type === "boolean" ? (
                      <div className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          id={param.name}
                          checked={params[param.name] || false}
                          onChange={(e) =>
                            handleParamChange(param.name, e.target.checked)
                          }
                          className="h-4 w-4"
                        />
                        <span className="text-sm">
                          {params[param.name] ? "Oui" : "Non"}
                        </span>
                      </div>
                    ) : param.type === "json" ? (
                      <textarea
                        id={param.name}
                        value={params[param.name] || "{}"}
                        onChange={(e) =>
                          handleParamChange(param.name, e.target.value)
                        }
                        className="w-full rounded-md border p-2 font-mono text-sm"
                        rows={4}
                        placeholder='{"key": "value"}'
                      />
                    ) : (
                      <Input
                        id={param.name}
                        type={
                          param.type === "number"
                            ? "number"
                            : param.type === "date"
                              ? "date"
                              : "text"
                        }
                        value={params[param.name] || param.defaultValue || ""}
                        onChange={(e) =>
                          handleParamChange(
                            param.name,
                            param.type === "number"
                              ? Number(e.target.value)
                              : e.target.value
                          )
                        }
                        placeholder={
                          param.defaultValue
                            ? `Défaut: ${param.defaultValue}`
                            : undefined
                        }
                      />
                    )}
                  </div>
                ))}
              </div>
            )}

            <div className="pt-4">
              <Button
                onClick={handleExecute}
                disabled={!isValid || loading}
                className="w-full"
              >
                {loading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Exécution en cours...
                  </>
                ) : (
                  <>
                    <Play className="mr-2 h-4 w-4" />
                    Exécuter la fonction
                  </>
                )}
              </Button>
            </div>
          </TabsContent>

          {/* Onglet Résultats */}
          <TabsContent value="results" className="space-y-4">
            {error && (
              <Alert variant="destructive">
                <XCircle className="h-4 w-4" />
                <AlertDescription className="ml-2">{error}</AlertDescription>
              </Alert>
            )}

            {result && (
              <div className="space-y-4">
                <Alert>
                  <CheckCircle className="h-4 w-4 text-green-600" />
                  <AlertDescription className="ml-2">
                    Fonction exécutée avec succès
                  </AlertDescription>
                </Alert>

                <div className="rounded-md border bg-muted/50 p-4">
                  <div className="mb-2 flex items-center gap-2 text-sm font-medium">
                    <Eye className="h-4 w-4" />
                    Résultat
                  </div>
                  <pre className="overflow-auto text-xs">
                    {JSON.stringify(result, null, 2)}
                  </pre>
                </div>
              </div>
            )}

            {!result && !error && (
              <div className="py-8 text-center text-sm text-muted-foreground">
                Aucun résultat. Exécutez la fonction d'abord.
              </div>
            )}
          </TabsContent>

          {/* Onglet SQL */}
          <TabsContent value="sql">
            <div className="rounded-md border bg-muted/50 p-4">
              <div className="mb-2 flex items-center gap-2 text-sm font-medium">
                <Code className="h-4 w-4" />
                Requête SQL
              </div>
              <pre className="overflow-auto text-xs font-mono">
                {`SELECT * FROM ${rpcFunction.name}(${rpcFunction.parameters
                  .map((p) => `p_${p.name} := ${params[p.name] || "NULL"}`)
                  .join(", ")});`}
              </pre>
            </div>
          </TabsContent>
        </Tabs>
      </CardContent>
    </Card>
  );
}

/**
 * Liste de fonctions RPC avec interface de recherche
 */
export interface RPCFunctionListProps {
  functions: RPCFunction[];
  onExecute: (functionName: string, params: Record<string, any>) => Promise<any>;
}

export function RPCFunctionList({ functions, onExecute }: RPCFunctionListProps) {
  const [selectedFunction, setSelectedFunction] = useState<RPCFunction | null>(
    functions[0] || null
  );

  return (
    <div className="grid gap-6 lg:grid-cols-[300px_1fr]">
      {/* Liste des fonctions */}
      <div className="space-y-2">
        <h3 className="text-sm font-medium">Fonctions disponibles</h3>
        <div className="space-y-1">
          {functions.map((fn) => (
            <button
              key={fn.name}
              onClick={() => setSelectedFunction(fn)}
              className={`w-full rounded-md px-3 py-2 text-left text-sm transition-colors ${
                selectedFunction?.name === fn.name
                  ? "bg-primary text-primary-foreground"
                  : "hover:bg-muted"
              }`}
            >
              <div className="font-medium">{fn.label}</div>
              {fn.category && (
                <div className="text-xs opacity-80">{fn.category}</div>
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Panneau de la fonction sélectionnée */}
      <div>
        {selectedFunction ? (
          <RPCPanel
            rpcFunction={selectedFunction}
            onExecute={(params) => onExecute(selectedFunction.name, params)}
            showResults
            showSQL
          />
        ) : (
          <Card>
            <CardContent className="py-8 text-center text-muted-foreground">
              Sélectionnez une fonction à gauche
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}
