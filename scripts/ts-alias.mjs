/**
 * `@/...` 를 저장소 루트 기준으로 푸는 Node resolve 훅.
 *
 * tsconfig의 paths는 Node가 읽지 않고, vitest는 자기 설정으로 별칭을 풀지만
 * 스크립트는 vitest 밖에서 돈다. 스크립트 실행 전용이며 앱 번들에는 들어가지 않는다.
 *
 * 쓰는 법: node --import ./scripts/ts-alias.mjs scripts/<script>.ts
 */
import { registerHooks } from 'node:module'
import { existsSync } from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

const root = path.resolve(import.meta.dirname, '..')

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (!specifier.startsWith('@/')) return nextResolve(specifier, context)

    const base = path.join(root, specifier.slice(2))
    const target = existsSync(base) ? base : `${base}.ts`
    return nextResolve(pathToFileURL(target).href, context)
  },
})
