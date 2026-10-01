/**
 * Emulator tests for firestore.rules.
 *
 * These exist because the rules are the only thing standing between a signed
 * in employee and everybody's salary. A rule that looks right in review can
 * still be wrong, and the two bugs that made this test file necessary — an
 * employee being able to set their own role to admin, and any employee being
 * able to read a colleague's salary slip — were both invisible by reading the
 * rules alone.
 *
 * Run with: npm run rules:test
 */
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing'
import { readFileSync } from 'node:fs'
import { beforeAll, beforeEach, describe, it } from 'vitest'
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, addDoc } from 'firebase/firestore'

let env: RulesTestEnvironment

const COMPANY = 'company-1'
const OTHER_COMPANY = 'company-2'

// Overridable so a candidate rules file can be verified without editing the
// real one: RULES_PATH=../firestore.rules.candidate npm run rules:test
const RULES_PATH = process.env.RULES_PATH ?? '../firestore.rules'

async function signIn(env: RulesTestEnvironment, uid: string, role: string, companyId = COMPANY) {
  return env.authenticatedContext(uid, { role, companyId }).firestore()
}

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-smart-hrms',
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
    },
  })
})

beforeEach(async () => {
  await env.clearFirestore()
  // Seeded as the emulator, so the data bypasses the rules under test.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore()
    await setDoc(doc(db, 'companies', COMPANY), {
      name: 'Brilliants',
      adminIds: ['admin-1'],
    })
    await setDoc(doc(db, 'companies', OTHER_COMPANY), {
      name: 'Other Co',
      adminIds: ['admin-2'],
    })
    await setDoc(doc(db, 'users', 'admin-1'), {
      name: 'Admin One',
      role: 'admin',
      companyId: COMPANY,
    })
    await setDoc(doc(db, 'users', 'hr-1'), {
      name: 'HR One',
      role: 'hr',
      companyId: COMPANY,
    })
    await setDoc(doc(db, 'users', 'emp-1'), {
      name: 'Employee One',
      role: 'employee',
      companyId: COMPANY,
    })
    await setDoc(doc(db, 'users', 'emp-2'), {
      name: 'Employee Two',
      role: 'employee',
      companyId: COMPANY,
    })
    await setDoc(doc(db, 'users', 'outsider-1'), {
      name: 'Outsider',
      role: 'employee',
      companyId: OTHER_COMPANY,
    })
  })
})

describe('privilege escalation', () => {
  it('refuses to let an employee make themselves an admin', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(updateDoc(doc(db, 'users', 'emp-1'), { role: 'admin' }))
  })

  it('refuses to let an employee move themselves to another company', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(updateDoc(doc(db, 'users', 'emp-1'), { companyId: OTHER_COMPANY }))
  })

  it('refuses to let an employee change their own status', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(updateDoc(doc(db, 'users', 'emp-1'), { status: 'On Leave' }))
  })

  it('lets an employee update their own phone number', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertSucceeds(updateDoc(doc(db, 'users', 'emp-1'), { phone: '9999999999' }))
  })

  it('stops an admin moving a user into a different company', async () => {
    const db = await signIn(env, 'admin-1', 'admin')

    await assertFails(updateDoc(doc(db, 'users', 'emp-1'), { companyId: OTHER_COMPANY }))
  })

  it('lets an admin change a colleague status when approving leave', async () => {
    const db = await signIn(env, 'admin-1', 'admin')

    await assertSucceeds(updateDoc(doc(db, 'users', 'emp-1'), { status: 'On Leave' }))
  })

  it('refuses to let an employee read a colleague profile', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(getDoc(doc(db, 'users', 'emp-2')))
  })

  it('refuses to let an employee create a user', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(
      setDoc(doc(db, 'users', 'new-employee'), {
        name: 'Backdoor',
        role: 'admin',
        companyId: COMPANY,
      }),
    )
  })
})

describe('salary slips', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore()
      await setDoc(doc(db, 'companies', COMPANY, 'salary_slips', 'slip-1'), {
        employeeId: 'emp-1',
        netSalary: 50000,
      })
      await setDoc(doc(db, 'companies', COMPANY, 'salary_slips', 'slip-2'), {
        employeeId: 'emp-2',
        netSalary: 60000,
      })
    })
  })

  it('lets an employee read their own slip', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertSucceeds(getDoc(doc(db, 'companies', COMPANY, 'salary_slips', 'slip-1')))
  })

  it('refuses to let an employee read a colleague salary slip', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(getDoc(doc(db, 'companies', COMPANY, 'salary_slips', 'slip-2')))
  })

  it('refuses to let an outsider read any slip', async () => {
    const db = await signIn(env, 'outsider-1', 'employee', OTHER_COMPANY)

    await assertFails(getDoc(doc(db, 'companies', COMPANY, 'salary_slips', 'slip-1')))
  })

  it('lets HR read the company slips', async () => {
    const db = await signIn(env, 'hr-1', 'hr')

    await assertSucceeds(getDoc(doc(db, 'companies', COMPANY, 'salary_slips', 'slip-2')))
  })

  it('refuses to let an employee write their own slip to a higher amount', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(
      updateDoc(doc(db, 'companies', COMPANY, 'salary_slips', 'slip-1'), { netSalary: 999999 }),
    )
  })
})

describe('leave requests', () => {
  it('lets an employee raise their own pending request', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertSucceeds(
      addDoc(collection(db, 'companies', COMPANY, 'leaves'), {
        employeeId: 'emp-1',
        uid: 'emp-1',
        name: 'Employee One',
        type: 'casual',
        reason: 'Family function',
        days: 1,
        status: 'pending',
      }),
    )
  })

  it('refuses to let an employee create a request already marked approved', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(
      addDoc(collection(db, 'companies', COMPANY, 'leaves'), {
        employeeId: 'emp-1',
        uid: 'emp-1',
        name: 'Employee One',
        type: 'casual',
        reason: 'Self approved leave',
        days: 30,
        status: 'approved',
      }),
    )
  })

  it('refuses to let an employee approve their own leave', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'companies', COMPANY, 'leaves', 'leave-1'), {
        employeeId: 'emp-1',
        uid: 'emp-1',
        status: 'pending',
        days: 1,
      })
    })
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(updateDoc(doc(db, 'companies', COMPANY, 'leaves', 'leave-1'), { status: 'approved' }))
  })

  it('lets HR approve a leave', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'companies', COMPANY, 'leaves', 'leave-1'), {
        employeeId: 'emp-1',
        uid: 'emp-1',
        status: 'pending',
        days: 1,
      })
    })
    const db = await signIn(env, 'hr-1', 'hr')

    await assertSucceeds(
      updateDoc(doc(db, 'companies', COMPANY, 'leaves', 'leave-1'), { status: 'approved' }),
    )
  })

  it('refuses to let a colleague read a leave request', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'companies', COMPANY, 'leaves', 'leave-1'), {
        employeeId: 'emp-1',
        uid: 'emp-1',
        status: 'pending',
        days: 1,
      })
    })
    const db = await signIn(env, 'emp-2', 'employee')

    await assertFails(getDoc(doc(db, 'companies', COMPANY, 'leaves', 'leave-1')))
  })
})

describe('attendance', () => {
  it('lets an employee punch in for themselves', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertSucceeds(
      addDoc(collection(db, 'companies', COMPANY, 'attendance'), {
        employeeId: 'emp-1',
        name: 'Employee One',
        date: '2026-01-01',
        punchIn: null,
        punchOut: null,
        status: 'present',
        isLate: false,
      }),
    )
  })

  it('refuses to let an employee punch in on behalf of somebody else', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(
      addDoc(collection(db, 'companies', COMPANY, 'attendance'), {
        employeeId: 'emp-2',
        name: 'Employee Two',
        date: '2026-01-01',
        punchIn: null,
        punchOut: null,
        status: 'present',
        isLate: false,
      }),
    )
  })

  it('refuses to let an employee edit a colleague attendance', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'companies', COMPANY, 'attendance', 'att-2'), {
        employeeId: 'emp-2',
        status: 'absent',
      })
    })
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(
      updateDoc(doc(db, 'companies', COMPANY, 'attendance', 'att-2'), { status: 'present' }),
    )
  })

  it('lets an admin correct any attendance record', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'companies', COMPANY, 'attendance', 'att-2'), {
        employeeId: 'emp-2',
        status: 'absent',
      })
    })
    const db = await signIn(env, 'admin-1', 'admin')

    await assertSucceeds(
      updateDoc(doc(db, 'companies', COMPANY, 'attendance', 'att-2'), { status: 'present' }),
    )
  })

  it('lets an employee read their own attendance only', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore()
      await setDoc(doc(db, 'companies', COMPANY, 'attendance', 'att-1'), { employeeId: 'emp-1' })
      await setDoc(doc(db, 'companies', COMPANY, 'attendance', 'att-2'), { employeeId: 'emp-2' })
    })
    const db = await signIn(env, 'emp-1', 'employee')

    await assertSucceeds(getDoc(doc(db, 'companies', COMPANY, 'attendance', 'att-1')))
    await assertFails(getDoc(doc(db, 'companies', COMPANY, 'attendance', 'att-2')))
  })
})

describe('employees, announcements and companies', () => {
  it('refuses to let an employee create another employee', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(
      setDoc(doc(db, 'companies', COMPANY, 'employees', 'emp-3'), {
        name: 'Injected',
        role: 'admin',
      }),
    )
  })

  it('lets an employee read their own employee record only', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore()
      await setDoc(doc(db, 'companies', COMPANY, 'employees', 'emp-1'), { name: 'Employee One' })
      await setDoc(doc(db, 'companies', COMPANY, 'employees', 'emp-2'), { name: 'Employee Two' })
    })
    const db = await signIn(env, 'emp-1', 'employee')

    await assertSucceeds(getDoc(doc(db, 'companies', COMPANY, 'employees', 'emp-1')))
    await assertFails(getDoc(doc(db, 'companies', COMPANY, 'employees', 'emp-2')))
  })

  it('refuses to let an employee post an announcement', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(
      addDoc(collection(db, 'companies', COMPANY, 'announcements'), { title: 'Fake' }),
    )
  })

  it('refuses to let an outsider read the company record', async () => {
    const db = await signIn(env, 'outsider-1', 'employee', OTHER_COMPANY)

    await assertFails(getDoc(doc(db, 'companies', COMPANY)))
  })

  it('refuses to let an employee edit the company record', async () => {
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(updateDoc(doc(db, 'companies', COMPANY), { name: 'Hacked' }))
  })

  it('refuses everything to a signed out caller', async () => {
    const db = env.unauthenticatedContext().firestore()

    await assertFails(getDoc(doc(db, 'companies', COMPANY, 'salary_slips', 'slip-1')))
    await assertFails(
      addDoc(collection(db, 'companies', COMPANY, 'attendance'), { employeeId: 'emp-1' }),
    )
  })

  it('refuses to let an employee delete an import log', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'import_logs', 'log-1'), {
        adminId: 'admin-1',
        companyId: COMPANY,
      })
    })
    const db = await signIn(env, 'emp-1', 'employee')

    await assertFails(deleteDoc(doc(db, 'import_logs', 'log-1')))
  })
})