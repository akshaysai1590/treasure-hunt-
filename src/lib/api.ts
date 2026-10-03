import { supabase } from "./supabase";

const MAX_RETRIES = 3;
const BASE_DELAY = 1000;

export async function callRpc<T>(rpcName: string, args: any = {}): Promise<T> {
  let attempt = 0;
  
  while (attempt < MAX_RETRIES) {
    try {
      const { data, error } = await supabase.rpc(rpcName, args);
      
      if (error) {
        throw error;
      }
      
      return data as T;
    } catch (err: any) {
      attempt++;
      if (attempt >= MAX_RETRIES) {
        throw err;
      }
      // Exponential backoff
      await new Promise(resolve => setTimeout(resolve, BASE_DELAY * Math.pow(2, attempt - 1)));
    }
  }
  
  throw new Error("RPC call failed after retries");
}
