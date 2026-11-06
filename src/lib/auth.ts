/**
 * Demo authentication seam. Phase 1+ can replace `getCurrentUser` with a
 * session lookup without touching the screens that consume it.
 */
export type Role = "owner" | "pharmacist" | "cashier";

export interface CurrentUser {
  id: string;
  name: string;
  role: Role;
}

const DEMO_USER: CurrentUser = {
  id: "demo",
  name: "Utilisateur démo",
  role: "owner",
};

export function getCurrentUser(): CurrentUser {
  return DEMO_USER;
}
