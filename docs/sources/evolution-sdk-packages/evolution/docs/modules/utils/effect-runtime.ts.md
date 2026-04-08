---
title: utils/effect-runtime.ts
nav_order: 188
parent: Modules
---

## effect-runtime overview

---

<h2 class="text-delta">Table of contents</h2>

- [utilities](#utilities)
  - [runEffect](#runeffect)
  - [runEffectPromise](#runeffectpromise)

---

# utilities

## runEffect

Run an Effect synchronously with clean error handling.

- Executes the Effect using Effect.runSyncExit
- On failure, extracts the error from the Exit and cleans stack traces
- Removes Effect.ts internal stack frames for cleaner error messages
- Throws the cleaned error for standard error handling

**Signature**

```ts
export declare function runEffect<A, E>(effect: Effect.Effect<A, E>): A
```

**Example**

```typescript
import { Effect } from "effect"
import { runEffect } from "@evolution-sdk/evolution/utils/effect-runtime"

const myEffect = Effect.succeed(42)

try {
  const result = runEffect(myEffect)
  console.log(result)
} catch (error) {
  // Error with clean stack trace, no Effect.ts internals
  console.error(error)
}
```

Added in v2.0.0

## runEffectPromise

Run an Effect asynchronously and convert it to a Promise with clean error handling.

- Executes the Effect using Effect.runPromiseExit
- On failure, extracts the error from the Exit and cleans stack traces
- Removes Effect.ts internal stack frames for cleaner error messages
- Throws the cleaned error for standard Promise error handling

**Signature**

```ts
export async function runEffectPromise<A, E>(effect: Effect.Effect<A, E>): Promise<A>
```

**Example**

```typescript
import { Effect } from "effect"
import { runEffectPromise } from "@evolution-sdk/evolution/utils/effect-runtime"

const myEffect = Effect.succeed(42)

async function example() {
  try {
    const result = await runEffectPromise(myEffect)
    console.log(result)
  } catch (error) {
    // Error with clean stack trace, no Effect.ts internals
    console.error(error)
  }
}
```

Added in v2.0.0
