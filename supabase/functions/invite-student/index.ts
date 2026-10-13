import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    if (!authHeader.startsWith('Bearer ')) throw new Error('Authentication required.')

    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const callerClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: authData, error: authError } = await callerClient.auth.getUser()
    if (authError || !authData.user) throw new Error('Invalid session.')

    const service = createClient(url, serviceKey)
    const { data: profile, error: profileError } = await service
      .from('users')
      .select('data')
      .eq('id', authData.user.id)
      .single()
    if (profileError) throw profileError
    if ((profile?.data?.role ?? '').toLowerCase() !== 'admin') {
      throw new Error('Only an MSCAS administrator can invite accounts.')
    }

    const body = await req.json()
    const email = String(body.email ?? '').trim().toLowerCase()
    const role = String(body.role ?? 'student').trim().toLowerCase()
    if (!email || !email.includes('@')) throw new Error('A valid email is required.')
    if (!['student', 'instructor', 'admin'].includes(role)) throw new Error('Invalid role.')

    const metadata = {
      first_name: String(body.first_name ?? '').trim(),
      last_name: String(body.last_name ?? '').trim(),
      role,
      student_number: String(body.student_number ?? '').trim(),
      course: String(body.course ?? '').trim(),
      year_level: Number(body.year_level ?? 1),
      employee_number: String(body.employee_number ?? '').trim(),
      department: String(body.department ?? '').trim(),
      onboarding_required: true,
    }

    const { data, error } = await service.auth.admin.inviteUserByEmail(email, {
      data: metadata,
      redirectTo: 'https://mscas-attendance.netlify.app/',
    })
    if (error) throw error

    if (data.user) {
      await service.from('users').update({
        data: {
          email,
          ...metadata,
          active: true,
          onboarding_pending: true,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      }).eq('id', data.user.id)
    }

    return new Response(JSON.stringify({
      success: true,
      user_id: data.user?.id ?? '',
      message: `Invitation sent to ${email}.`,
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      message: error instanceof Error ? error.message : String(error),
    }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
