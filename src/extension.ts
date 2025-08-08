import * as vscode from "vscode";

import { configureCommands } from "./commands";
import { detectConflictingExtensions } from "./conflictingExtensions";
import { configureDebugger } from "./debugAdapter";
import { DefinitionTool } from "./definition-tool";
import { DocsAggregatorTool } from "./docs-aggregator-tool";
import { EnvironmentTool } from "./environment-tool";
import { ImplementationFinderTool } from "./implementation-finder-tool";
import { LanguageClientManager } from "./languageClientManager";
import { ModuleDependenciesTool } from "./module-dependencies-tool";
import { WorkspaceTracker } from "./project";
import { TaskProvider } from "./taskProvider";
import { configureTelemetry, reporter } from "./telemetry";
import { configureTerminalLinkProvider } from "./terminalLinkProvider";
import {
  configureTestController,
  handleWorkspaceFolderRemoved as handleTestControllerWorkspaceFolderRemoved,
} from "./testController";
import { testElixir } from "./testElixir";
import { TypeInfoTool } from "./type-info-tool";
import { E2ETestController } from "./e2eTestController";

console.log("ElixirLS: Loading extension");

export interface ElixirLS {
  workspaceTracker: WorkspaceTracker;
  languageClientManager: LanguageClientManager;
}

export const workspaceTracker = new WorkspaceTracker();
export const languageClientManager = new LanguageClientManager(
  workspaceTracker,
);

const startClientsForOpenDocuments = (context: vscode.ExtensionContext) => {
  // biome-ignore lint/complexity/noForEach: iterating with forEach keeps the initialization straightforward
  vscode.workspace.textDocuments.forEach((value) => {
    languageClientManager.handleDidOpenTextDocument(value, context);
  });
};

export function activate(context: vscode.ExtensionContext): ElixirLS {
  console.log("ElixirLS: activating extension in mode", workspaceTracker.mode);
  console.log(
    "ElixirLS: Workspace folders are",
    vscode.workspace.workspaceFolders,
  );
  console.log(
    "ElixirLS: Workspace is",
    vscode.workspace.workspaceFile?.toString(),
  );

  configureTelemetry(context);

  reporter.sendTelemetryEvent("extension_activated", {
    "elixir_ls.workspace_mode": workspaceTracker.mode,
  });

  context.subscriptions.push(
    vscode.workspace.onDidChangeWorkspaceFolders(() => {
      console.info(
        "ElixirLS: Workspace folders changed",
        vscode.workspace.workspaceFolders,
      );
      workspaceTracker.handleDidChangeWorkspaceFolders();
    }),
  );

  testElixir(context);

  detectConflictingExtensions();

  // Create IDE Coordinator output channel for debugging
  const ideCoordinatorOutputChannel = vscode.window.createOutputChannel('IDE Coordinator');

  configureCommands(context, languageClientManager);
  configureDebugger(context, ideCoordinatorOutputChannel, (workspaceFolder) => 
    workspaceFolder ? 
      languageClientManager.getClientByUri(workspaceFolder.uri) : 
      languageClientManager.getDefaultClient());
  configureTerminalLinkProvider(context);
  configureTestController(context, languageClientManager, workspaceTracker);

  // Initialize E2E Test Controller for IDE Coordinator testing
  const e2eTestController = new E2ETestController();
  e2eTestController.registerCommands(context);
  context.subscriptions.push(e2eTestController);

  context.subscriptions.push(
    vscode.workspace.onDidOpenTextDocument((value) => {
      languageClientManager.handleDidOpenTextDocument(value, context);
    }),
  );

  startClientsForOpenDocuments(context);

  // Register language model tool for all clients
  const registerLanguageModelTool = async () => {
    const clientPromises = languageClientManager.allClientsPromises();

    for (const [_uri, clientPromise] of clientPromises.entries()) {
      try {
        const client = await clientPromise;

        // Register definition tool
        const definitionTool = new DefinitionTool(client);
        context.subscriptions.push(
          vscode.lm.registerTool("elixir-definition", definitionTool),
        );

        // Register environment tool
        const environmentTool = new EnvironmentTool(client);
        context.subscriptions.push(
          vscode.lm.registerTool("elixir-environment", environmentTool),
        );

        // Register module dependencies tool
        const moduleDependenciesTool = new ModuleDependenciesTool(client);
        context.subscriptions.push(
          vscode.lm.registerTool(
            "elixir-module-dependencies",
            moduleDependenciesTool,
          ),
        );

        // Register implementation finder tool
        const implementationFinderTool = new ImplementationFinderTool(client);
        context.subscriptions.push(
          vscode.lm.registerTool(
            "elixir-implementation-finder",
            implementationFinderTool,
          ),
        );

        // Register documentation aggregator tool
        const docsAggregatorTool = new DocsAggregatorTool(client);
        context.subscriptions.push(
          vscode.lm.registerTool("elixir-docs", docsAggregatorTool),
        );

        // Register type info tool
        const typeInfoTool = new TypeInfoTool(client);
        context.subscriptions.push(
          vscode.lm.registerTool("elixir-types", typeInfoTool),
        );

        console.log("ElixirLS: Registered language model tools for client");
        // Only register once - all clients share the same command namespace
        break;
      } catch (error) {
        console.error(
          "ElixirLS: Failed to register language model tool",
          error,
        );
      }
    }
  };

  // Register tool for existing clients
  registerLanguageModelTool();

  // Register tool when new clients are added
  context.subscriptions.push(
    vscode.workspace.onDidOpenTextDocument((_doc) => {
      // Small delay to ensure client is started
      setTimeout(registerLanguageModelTool, 1000);
    }),
  );

  context.subscriptions.push(
    vscode.workspace.onDidChangeWorkspaceFolders(async (event) => {
      for (const folder of event.removed) {
        await languageClientManager.handleWorkspaceFolderRemoved(folder);
        handleTestControllerWorkspaceFolderRemoved(folder);
      }
      // we might have closed client for some nested workspace folder child
      // reopen all needed
      startClientsForOpenDocuments(context);
      // Register tool for new clients
      setTimeout(registerLanguageModelTool, 1000);
    }),
  );

  context.subscriptions.push(
    vscode.tasks.registerTaskProvider(
      TaskProvider.TaskType,
      new TaskProvider(),
    ),
  );

  console.log("ElixirLS: extension activated");
  return {
    languageClientManager,
    workspaceTracker,
  };
}

export async function deactivate() {
  console.log("ElixirLS: deactivating extension");
  reporter.sendTelemetryEvent("extension_deactivated", {
    "elixir_ls.workspace_mode": workspaceTracker.mode,
  });
  workspaceTracker.handleDidChangeWorkspaceFolders();
  await languageClientManager.deactivate();
  console.log("ElixirLS: extension deactivated");
}
