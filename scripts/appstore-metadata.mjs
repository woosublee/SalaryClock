#!/usr/bin/env node
// appstore/metadata.json을 App Store Connect에 반영한다(App Store Connect API).
//
// 사용법:
//   node scripts/appstore-metadata.mjs                # 문구·카테고리·연령 등급·가격·심사 메모·빌드 연결
//   node scripts/appstore-metadata.mjs --screenshots  # 위에 더해 스크린샷도 갈아 끼운다
//
// 몇 번을 돌려도 같은 결과가 되게 짰다. 이미 있는 것은 고치고, 없는 것만 만든다.
// 심사 제출은 하지 않는다 — 화면에서 한 번 보고 사람이 누른다.
//
// API로 안 되는 것: 앱 개인정보(데이터 수집 여부)는 Apple이 API를 열어 두지 않아
// 웹에서 한 번 채운다(appstore/README.md).
//
// 인증은 scripts/appstore-release.sh와 같은 팀 API 키다. ASC_KEY_ID·ASC_ISSUER_ID·
// ASC_KEY_PATH로 바꿀 수 있고, 없으면 아래 기본값과 ~/.appstoreconnect/private_keys를 쓴다.
import { createHash, createPrivateKey, createSign } from 'node:crypto'
import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const BUNDLE_ID = 'dev.woosublee.salaryclock'
const KID = process.env.ASC_KEY_ID ?? '42NUW466H7'
const ISS = process.env.ASC_ISSUER_ID ?? '2899c1ee-804d-4040-85b1-e9183355b461'
const KEY_PATH = process.env.ASC_KEY_PATH ?? `${homedir()}/.appstoreconnect/private_keys/AuthKey_${KID}.p8`
const WITH_SCREENSHOTS = process.argv.includes('--screenshots')

const meta = JSON.parse(readFileSync(join(ROOT, 'appstore/metadata.json'), 'utf8'))
const release = JSON.parse(readFileSync(join(ROOT, 'release/version.json'), 'utf8'))

// --- API ---------------------------------------------------------------------

const b64 = (v) => Buffer.from(typeof v === 'string' ? v : JSON.stringify(v)).toString('base64url')
const key = createPrivateKey(readFileSync(KEY_PATH))
function token() {
  const now = Math.floor(Date.now() / 1000)
  const body = `${b64({ alg: 'ES256', kid: KID, typ: 'JWT' })}.${b64({ iss: ISS, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' })}`
  // JWT의 ES256 서명은 DER이 아니라 r‖s 64바이트다.
  const sig = createSign('SHA256').update(body).sign({ key, dsaEncoding: 'ieee-p1363' })
  return `${body}.${sig.toString('base64url')}`
}

async function api(method, path, body) {
  const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  })
  const text = await res.text()
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status}\n${text}`)
  return text ? JSON.parse(text) : null
}
const get = (p) => api('GET', p)
const patch = (type, id, attributes, relationships) =>
  api('PATCH', `/v1/${type}/${id}`, { data: { type, id, attributes, relationships } })
const create = (type, attributes, relationships) =>
  api('POST', `/v1/${type}`, { data: { type, attributes, relationships } })
const rel = (type, id) => ({ data: { type, id } })
const log = (...a) => console.log('  ', ...a)

// --- 앱 -----------------------------------------------------------------------

const app = (await get(`/v1/apps?filter[bundleId]=${BUNDLE_ID}`)).data[0]
if (!app) throw new Error(`App Store Connect에 ${BUNDLE_ID} 앱이 없다 — appstore/README.md의 "처음 한 번"`)
console.log(`== ${app.attributes.name} (${app.id})`)

// 앱 정보(이름·부제·카테고리·연령 등급)는 플랫폼 공통이다. 심사 중이 아닌,
// 고칠 수 있는 쪽을 고른다.
const appInfos = (await get(`/v1/apps/${app.id}/appInfos`)).data
const appInfo = appInfos.find((i) => i.attributes.state !== 'READY_FOR_DISTRIBUTION') ?? appInfos[0]
await patch('appInfos', appInfo.id, undefined, {
  primaryCategory: rel('appCategories', meta.primaryCategory),
  secondaryCategory: rel('appCategories', meta.secondaryCategory),
})
log('카테고리', meta.primaryCategory, meta.secondaryCategory)

const infoLocs = (await get(`/v1/appInfos/${appInfo.id}/appInfoLocalizations`)).data
const infoLoc = infoLocs.find((l) => l.attributes.locale === meta.locale)
await patch('appInfoLocalizations', infoLoc.id, {
  subtitle: meta.subtitle,
  privacyPolicyUrl: meta.privacyPolicyUrl,
})
log('부제·개인정보 처리방침 URL')

// 연령 등급: 모든 항목 "없음" → 4+. 항목은 Apple이 해마다 늘리므로 목록을 박지 않고,
// 지금 선언에 있는 키를 읽어 종류대로 채운다. 문자열은 빈도 항목(NONE)이고 나머지는
// 예/아니오다. 고정해 두는 override·한국 등급 같은 값은 건드리지 않는다.
{
  const decl = (await get(`/v1/appInfos/${appInfo.id}/ageRatingDeclaration`)).data
  const keep = new Set(['ageRatingOverride', 'ageRatingOverrideV2', 'koreaAgeRatingOverride', 'kidsAgeBand', 'gracRatingClassificationNumber', 'developerAgeRatingInfoUrl'])
  const FREQUENCY = new Set([
    'alcoholTobaccoOrDrugUseOrReferences', 'contests', 'gamblingSimulated', 'gunsOrOtherWeapons',
    'horrorOrFearThemes', 'matureOrSuggestiveThemes', 'medicalOrTreatmentInformation',
    'profanityOrCrudeHumor', 'sexualContentGraphicAndNudity', 'sexualContentOrNudity',
    'violenceCartoonOrFantasy', 'violenceRealistic', 'violenceRealisticProlongedGraphicOrSadistic',
  ])
  const attrs = {}
  for (const k of Object.keys(decl.attributes)) {
    if (keep.has(k)) continue
    attrs[k] = FREQUENCY.has(k) ? 'NONE' : false
  }
  await patch('ageRatingDeclarations', decl.id, attrs)
  log('연령 등급 (모두 없음)')
}

// --- 가격·판매 국가 -------------------------------------------------------------

{
  // 무료. 가격표가 이미 무료면 건드리지 않는다.
  const base = 'KOR'
  const points = (await get(`/v1/apps/${app.id}/appPricePoints?filter[territory]=${base}&limit=200`)).data
  const free = points.find((p) => Number(p.attributes.customerPrice) === 0)
  try {
    await api('POST', '/v1/appPriceSchedules', {
      data: {
        type: 'appPriceSchedules',
        relationships: {
          app: rel('apps', app.id),
          baseTerritory: rel('territories', base),
          manualPrices: { data: [{ type: 'appPrices', id: '${free}' }] },
        },
      },
      included: [{
        type: 'appPrices', id: '${free}',
        attributes: { startDate: null },
        relationships: { appPricePoint: rel('appPricePoints', free.id) },
      }],
    })
    log('가격 무료')
  } catch (e) {
    log('가격 설정 실패(이미 설정됐으면 무시해도 된다):', e.message.split('\n')[0])
  }

  // 판매 국가. 한국 공휴일·4대보험 기준이라 대한민국만.
  const territories = new Set(meta.territories)
  try {
    const existing = await get(`/v1/apps/${app.id}/appAvailabilityV2`).catch(() => null)
    if (existing?.data) {
      const tas = (await get(`/v2/appAvailabilities/${existing.data.id}/territoryAvailabilities?limit=200&include=territory`)).data
      for (const ta of tas) {
        const want = territories.has(ta.relationships?.territory?.data?.id)
        if (ta.attributes.available !== want) await patch('territoryAvailabilities', ta.id, { available: want })
      }
    } else {
      const all = (await get('/v1/territories?limit=200')).data.map((t) => t.id)
      await api('POST', '/v2/appAvailabilities', {
        data: {
          type: 'appAvailabilities',
          attributes: { availableInNewTerritories: false },
          relationships: {
            app: rel('apps', app.id),
            territoryAvailabilities: { data: all.map((t) => ({ type: 'territoryAvailabilities', id: `\${${t}}` })) },
          },
        },
        included: all.map((t) => ({
          type: 'territoryAvailabilities', id: `\${${t}}`,
          attributes: { available: territories.has(t) },
          relationships: { territory: rel('territories', t) },
        })),
      })
    }
    log('판매 국가', [...territories].join(','))
  } catch (e) {
    log('판매 국가 설정 실패:', e.message.split('\n')[0])
  }
}

// --- 플랫폼별 버전 --------------------------------------------------------------

const versions = (await get(`/v1/apps/${app.id}/appStoreVersions?limit=20`)).data
const builds = (await get(`/v1/builds?filter[app]=${app.id}&filter[version]=${release.buildNumber}&include=preReleaseVersion&limit=20`))
for (const platform of ['IOS', 'MAC_OS']) {
  // 고칠 수 있는 버전 하나. 첫 출시에는 App Store Connect가 "1.0"으로 만들어 두므로
  // version.json의 번호로 맞춘다 — 빌드의 CFBundleShortVersionString과 같아야 붙는다.
  const v = versions.find((x) => x.attributes.platform === platform && ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED'].includes(x.attributes.appStoreState))
  if (!v) { log(platform, '고칠 수 있는 버전이 없다 (심사 중이거나 출시됨)'); continue }
  console.log(`-- ${platform} ${release.marketingVersion}`)
  await patch('appStoreVersions', v.id, { versionString: release.marketingVersion, copyright: meta.copyright })

  const locs = (await get(`/v1/appStoreVersions/${v.id}/appStoreVersionLocalizations`)).data
  const attrs = {
    description: meta.description[platform],
    keywords: meta.keywords,
    promotionalText: meta.promotionalText,
    supportUrl: meta.supportUrl,
    marketingUrl: meta.marketingUrl,
  }
  let loc = locs.find((l) => l.attributes.locale === meta.locale)
  if (loc) await patch('appStoreVersionLocalizations', loc.id, attrs)
  else loc = (await create('appStoreVersionLocalizations', { ...attrs, locale: meta.locale }, { appStoreVersion: rel('appStoreVersions', v.id) })).data
  log('설명·키워드·프로모션 텍스트·URL')

  // 심사 메모와 연락처. 전화번호는 저장소에 두지 않는다 — 화면에서 직접 넣는다.
  const review = { ...meta.review, demoAccountRequired: false }
  const detail = await get(`/v1/appStoreVersions/${v.id}/appStoreReviewDetail`).catch(() => null)
  if (detail?.data) await patch('appStoreReviewDetails', detail.data.id, review)
  else await create('appStoreReviewDetails', review, { appStoreVersion: rel('appStoreVersions', v.id) })
  log('심사 메모')

  // 빌드 연결. version.json의 빌드 번호와 같고 처리가 끝난 것만.
  const pre = new Map((builds.included ?? []).map((p) => [p.id, p.attributes]))
  const build = builds.data.find((b) => pre.get(b.relationships.preReleaseVersion.data.id)?.platform === platform)
  if (!build) log('빌드', release.buildNumber, '아직 없음 — 업로드 후 다시 돌릴 것')
  else if (build.attributes.processingState !== 'VALID') log('빌드', release.buildNumber, '처리 중:', build.attributes.processingState)
  else {
    await api('PATCH', `/v1/appStoreVersions/${v.id}/relationships/build`, rel('builds', build.id))
    log('빌드', release.buildNumber, '연결')
  }

  if (WITH_SCREENSHOTS) await uploadScreenshots(platform, loc.id)
}

// --- 스크린샷 -------------------------------------------------------------------

async function uploadScreenshots(platform, locId) {
  const entries = Object.entries(meta.screenshots).filter(([type]) =>
    platform === 'MAC_OS' ? type.startsWith('APP_DESKTOP') : !type.startsWith('APP_DESKTOP'))
  for (const [displayType, dir] of entries) {
    const abs = join(ROOT, dir)
    const files = existsSync(abs) ? readdirSync(abs).filter((f) => f.endsWith('.png')).sort() : []
    if (files.length === 0) { log(displayType, `스크린샷 없음 (${dir})`); continue }

    // 같은 종류의 세트가 있으면 안의 것을 다 지우고 새로 올린다. 순서가 파일 이름 순이
    // 되게 하는 가장 단순한 방법이다.
    const sets = (await get(`/v1/appStoreVersionLocalizations/${locId}/appScreenshotSets`)).data
    let set = sets.find((s) => s.attributes.screenshotDisplayType === displayType)
    if (set) {
      for (const old of (await get(`/v1/appScreenshotSets/${set.id}/appScreenshots`)).data)
        await api('DELETE', `/v1/appScreenshots/${old.id}`)
    } else {
      set = (await create('appScreenshotSets', { screenshotDisplayType: displayType }, { appStoreVersionLocalization: rel('appStoreVersionLocalizations', locId) })).data
    }

    for (const name of files) {
      const bytes = readFileSync(join(abs, name))
      const shot = (await create('appScreenshots', { fileName: name, fileSize: bytes.length }, { appScreenshotSet: rel('appScreenshotSets', set.id) })).data
      // Apple이 알려준 조각대로 나눠 PUT한다.
      for (const op of shot.attributes.uploadOperations) {
        const res = await fetch(op.url, {
          method: op.method,
          headers: Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value])),
          body: bytes.subarray(op.offset, op.offset + op.length),
        })
        if (!res.ok) throw new Error(`스크린샷 업로드 실패 ${name}: ${res.status}`)
      }
      await patch('appScreenshots', shot.id, { uploaded: true, sourceFileChecksum: createHash('md5').update(bytes).digest('hex') })
    }
    log(displayType, `스크린샷 ${files.length}장`)
  }
}

console.log('끝. 앱 개인정보는 웹에서 — 심사 제출도 화면에서 확인 후 직접.')
