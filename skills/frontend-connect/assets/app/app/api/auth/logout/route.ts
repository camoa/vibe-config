import { NextResponse } from "next/server";
import { getSession } from "@/lib/session";

export async function POST() {
  (await getSession()).destroy();
  const base = process.env.DRUPAL_BASE_URL!.replace(/\/$/, "");
  return NextResponse.redirect(`${base}/user/logout`, 303);
}
