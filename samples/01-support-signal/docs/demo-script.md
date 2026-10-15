# A five-minute demo

For a live presentation, use your own configured app and authorize the inference charges. On Azure hosting, sign in with an allowed account: the header shows **Azure App Service** and the engine is **Microsoft Foundry · MAF**; simulation is disabled. You can also run [the local app against your Foundry deployment](../README.md#run-with-microsoft-foundry): its header shows **Local development**, and it uses Azure CLI credentials rather than the hosted managed identity. No maintainer-hosted application is required.

For a presentation without Azure, use the explicitly labeled local simulation and say that no model or MAF is running. It teaches the application workflow, not live model behavior.

**Audience:** developers learning their first model-backed application. **Takeaway:** Foundry supplies inference; application checks and human review remain explicit responsibilities.

| Time | Show and explain |
| --- | --- |
| 0:00-0:30 | Introduce the problem: how do we turn a support request into a reviewable proposal? |
| 0:30-1:00 | Point to the engine above the input and the execution strip. In the hosted path, MAF calls the Foundry deployment using the app's managed identity; App Service hosts the application. |
| 1:00-2:00 | Predict, then analyze **Service outage** once. Explain category, proposed priority, and the quoted evidence. Model prose and timing vary; do not promise the historical result. |
| 2:00-2:45 | Open **Inspect this decision** for readable checks and review policy. Leave nested JSON closed unless asked. Valid structure and a quote do not prove correct interpretation. |
| 2:45-3:30 | Edit the reply, approve it, then edit again to clear approval. Export and distinguish original output from human edits. Nothing is sent. |
| 3:30-4:15 | Close with one code-defined agent, Foundry inference, application validation, and a human decision. Tools and multi-agent orchestration are unnecessary for this slice. |
| 4:15-5:00 | Buffer for response latency or one question. Stop and show any failure honestly rather than substituting a simulated success. |

The allocation totals 300 seconds; delivery and live latency must be rehearsed. Outside the timed path, try **Unclear request** only with authorization for another billed request. The instructions ask for General and clarification, but the application does not verify that semantic interpretation.

Before the session, with authorized consumption, open the app and analyze one synthetic request: on 2026-10-14 the first request after a shared-plan restart timed out and the next one succeeded. If Azure is unavailable, run `./Start-Demo.ps1 -Lab 1 -Offline`, choose **Local simulation**, state that no model or MAF is running, and compare with the recorded Azure result in the [guided lab](guided-lab.md#recorded-azure-run-and-evidence-limits).

The preview stack is an explicit experiment. This is not production readiness evidence. Never present simulation timings as model latency.
