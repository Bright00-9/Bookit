import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const B2_KEY_ID = Deno.env.get('005b3f61f486e4b0000000001')!
const B2_APP_KEY = Deno.env.get('K0050DqJ/r75YIX4b7wUxpuzC+3AYZM')!
const B2_BUCKET_ID = Deno.env.get('db738f9611df54a896ee041b')!
const B2_BUCKET_NAME = Deno.env.get('moka-worker-videos')!
const B2_ENDPOINT = Deno.env.get('s3.us-east-005.backblazeb2.com')!

// ── Authorize B2 account ──────────────────────────────────
async function authorizeB2() {
  const credentials = btoa(`${B2_KEY_ID}:${B2_APP_KEY}`)
  const res = await fetch(
    'https://api.backblazeb2.com/b2api/v2/b2_authorize_account',
    {
      headers: {
        Authorization: `Basic ${credentials}`,
      },
    }
  )
  if (!res.ok) throw new Error('B2 authorization failed')
  return await res.json()
}

// ── Get upload URL from B2 ────────────────────────────────
async function getUploadUrl(authToken: string, apiUrl: string) {
  const res = await fetch(`${apiUrl}/b2api/v2/b2_get_upload_url`, {
    method: 'POST',
    headers: {
      Authorization: authToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ bucketId: B2_BUCKET_ID }),
  })
  if (!res.ok) throw new Error('Failed to get upload URL')
  return await res.json()
}

// ── Compute SHA1 ──────────────────────────────────────────
async function sha1Hex(data: Uint8Array): Promise<string> {
  const hashBuffer = await crypto.subtle.digest('SHA-1', data)
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

serve(async (req) => {
  try {
    const formData = await req.formData()
    const file = formData.get('video') as File
    const userId = formData.get('user_id') as string

    if (!file || !userId) {
      return new Response(
        JSON.stringify({ error: 'Missing video or user_id' }),
        { status: 400 }
      )
    }

    // Validate size (max 100MB) and type
    if (file.size > 100 * 1024 * 1024) {
      return new Response(
        JSON.stringify({ error: 'Video too large. Max 100MB.' }),
        { status: 400 }
      )
    }

    const bytes = new Uint8Array(await file.arrayBuffer())
    const sha1 = await sha1Hex(bytes)
    const fileName = `worker-videos/${userId}/${Date.now()}_work_video.mp4`

    // Authorize + get upload URL
    const auth = await authorizeB2()
    const uploadData = await getUploadUrl(
      auth.authorizationToken,
      auth.apiUrl
    )

    // Upload to B2
    const uploadRes = await fetch(uploadData.uploadUrl, {
      method: 'POST',
      headers: {
        Authorization: uploadData.authorizationToken,
        'X-Bz-File-Name': encodeURIComponent(fileName),
        'Content-Type': 'video/mp4',
        'Content-Length': bytes.length.toString(),
        'X-Bz-Content-Sha1': sha1,
      },
      body: bytes,
    })

    if (!uploadRes.ok) {
      const err = await uploadRes.text()
      throw new Error(`B2 upload failed: ${err}`)
    }

    const uploaded = await uploadRes.json()

    // Build public-friendly download URL
    const downloadUrl = `${auth.downloadUrl}/file/${B2_BUCKET_NAME}/${fileName}`

    return new Response(
      JSON.stringify({
        success: true,
        file_id: uploaded.fileId,
        file_name: uploaded.fileName,
        download_url: downloadUrl,
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ success: false, error: e.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})