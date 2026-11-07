/**
 * Hand-written database types for PharmaCare.
 *
 * These mirror `db/001_schema.sql` and `db/002_functions.sql`. If the SQL
 * changes, update this file in the same pull request. Regenerating with the
 * Supabase CLI is possible later, but the project intentionally keeps a
 * hand-written, reviewable contract for v1.
 *
 * Money is always an integer number of millimes (1 TND = 1000 millimes).
 * `bigint` columns are typed as `number`: all values in this application are
 * far below `Number.MAX_SAFE_INTEGER`.
 */

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

// ---------------------------------------------------------------------------
// Table rows
// ---------------------------------------------------------------------------

export type Category = {
  id: string;
  name: string;
  created_at: string;
};

export type Product = {
  id: string;
  name: string;
  barcode: string | null;
  category_id: string | null;
  price_millimes: number;
  cost_millimes: number;
  stock_quantity: number;
  low_stock_threshold: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

export type PaymentMethod = "cash";

export type Sale = {
  id: string;
  receipt_number: string;
  total_millimes: number;
  payment_method: PaymentMethod;
  created_at: string;
};

export type SaleItem = {
  id: string;
  sale_id: string;
  product_id: string | null;
  product_name: string;
  unit_price_millimes: number;
  quantity: number;
  line_total_millimes: number;
};

export type StockMovementReason = "sale" | "restock" | "adjustment";

export type StockMovement = {
  id: string;
  product_id: string;
  delta: number;
  reason: StockMovementReason;
  reference_id: string | null;
  note: string | null;
  created_at: string;
};

export type Settings = {
  id: number;
  pharmacy_name: string;
  address: string;
  phone: string;
  receipt_footer: string;
  updated_at: string;
};

// ---------------------------------------------------------------------------
// Insert / update helpers
// ---------------------------------------------------------------------------

export type CategoryInsert = {
  id?: string;
  name: string;
  created_at?: string;
};

export type CategoryUpdate = {
  id?: string;
  name?: string;
  created_at?: string;
};

export type ProductInsert = {
  id?: string;
  name: string;
  barcode?: string | null;
  category_id?: string | null;
  price_millimes: number;
  cost_millimes?: number;
  stock_quantity?: number;
  low_stock_threshold?: number;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
};

export type ProductUpdate = {
  id?: string;
  name?: string;
  barcode?: string | null;
  category_id?: string | null;
  price_millimes?: number;
  cost_millimes?: number;
  stock_quantity?: number;
  low_stock_threshold?: number;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
};

export type SaleInsert = {
  id?: string;
  receipt_number: string;
  total_millimes: number;
  payment_method?: PaymentMethod;
  created_at?: string;
};

export type SaleUpdate = {
  id?: string;
  receipt_number?: string;
  total_millimes?: number;
  payment_method?: PaymentMethod;
  created_at?: string;
};

export type SaleItemInsert = {
  id?: string;
  sale_id: string;
  product_id?: string | null;
  product_name: string;
  unit_price_millimes: number;
  quantity: number;
  line_total_millimes: number;
};

export type SaleItemUpdate = {
  id?: string;
  sale_id?: string;
  product_id?: string | null;
  product_name?: string;
  unit_price_millimes?: number;
  quantity?: number;
  line_total_millimes?: number;
};

export type StockMovementInsert = {
  id?: string;
  product_id: string;
  delta: number;
  reason: StockMovementReason;
  reference_id?: string | null;
  note?: string | null;
  created_at?: string;
};

export type StockMovementUpdate = {
  id?: string;
  product_id?: string;
  delta?: number;
  reason?: StockMovementReason;
  reference_id?: string | null;
  note?: string | null;
  created_at?: string;
};

export type SettingsInsert = {
  id?: number;
  pharmacy_name?: string;
  address?: string;
  phone?: string;
  receipt_footer?: string;
  updated_at?: string;
};

export type SettingsUpdate = {
  id?: number;
  pharmacy_name?: string;
  address?: string;
  phone?: string;
  receipt_footer?: string;
  updated_at?: string;
};

// ---------------------------------------------------------------------------
// RPC argument / result types
// ---------------------------------------------------------------------------

export type SaleItemInput = {
  product_id: string;
  quantity: number;
};

/** Snapshot returned by `create_sale`; prices come from the database. */
export type SaleItemSnapshot = {
  product_id: string;
  product_name: string;
  unit_price_millimes: number;
  quantity: number;
  line_total_millimes: number;
};

export type SaleResult = {
  sale_id: string;
  receipt_number: string;
  total_millimes: number;
  created_at: string;
  items: SaleItemSnapshot[];
};

/**
 * `today_avg_basket` is rounded to the nearest millime by the SQL function;
 * it is an integer, never a decimal.
 */
export type DashboardSummary = {
  today_revenue: number;
  today_sales: number;
  today_avg_basket: number;
  yesterday_revenue: number;
  yesterday_sales: number;
};

export type SalesTrendPoint = {
  day: string;
  revenue_millimes: number;
  sales_count: number;
};

export type TopProduct = {
  product_id: string;
  name: string;
  quantity: number;
  revenue_millimes: number;
};

export type LowStockProduct = {
  id: string;
  name: string;
  stock_quantity: number;
  low_stock_threshold: number;
};

export type StockSummary = {
  product_count: number;
  total_units: number;
  cost_value_millimes: number;
  retail_value_millimes: number;
};

// ---------------------------------------------------------------------------
// Database contract for @supabase/supabase-js
//
// Shape required by supabase-js 2.x: public.Tables / Views / Functions /
// Enums / CompositeTypes. Relationships are declared so embedded selects on
// products/categories and sale_items/sales type-check correctly.
// ---------------------------------------------------------------------------

export type Database = {
  __InternalSupabase: {
    PostgrestVersion: "12";
  };
  public: {
    Tables: {
      categories: {
        Row: Category;
        Insert: CategoryInsert;
        Update: CategoryUpdate;
        Relationships: [];
      };
      products: {
        Row: Product;
        Insert: ProductInsert;
        Update: ProductUpdate;
        Relationships: [
          {
            foreignKeyName: "products_category_id_fkey";
            columns: ["category_id"];
            isOneToOne: false;
            referencedRelation: "categories";
            referencedColumns: ["id"];
          },
        ];
      };
      sales: {
        Row: Sale;
        Insert: SaleInsert;
        Update: SaleUpdate;
        Relationships: [];
      };
      sale_items: {
        Row: SaleItem;
        Insert: SaleItemInsert;
        Update: SaleItemUpdate;
        Relationships: [
          {
            foreignKeyName: "sale_items_sale_id_fkey";
            columns: ["sale_id"];
            isOneToOne: false;
            referencedRelation: "sales";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "sale_items_product_id_fkey";
            columns: ["product_id"];
            isOneToOne: false;
            referencedRelation: "products";
            referencedColumns: ["id"];
          },
        ];
      };
      stock_movements: {
        Row: StockMovement;
        Insert: StockMovementInsert;
        Update: StockMovementUpdate;
        Relationships: [
          {
            foreignKeyName: "stock_movements_product_id_fkey";
            columns: ["product_id"];
            isOneToOne: false;
            referencedRelation: "products";
            referencedColumns: ["id"];
          },
        ];
      };
      settings: {
        Row: Settings;
        Insert: SettingsInsert;
        Update: SettingsUpdate;
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      create_sale: {
        Args: {
          p_items: SaleItemInput[];
        };
        Returns: SaleResult;
      };
      adjust_stock: {
        Args: {
          p_product_id: string;
          p_delta: number;
          p_note?: string | null;
        };
        Returns: number;
      };
      get_dashboard_summary: {
        Args: Record<PropertyKey, never>;
        Returns: DashboardSummary;
      };
      get_sales_trend: {
        Args: {
          p_days?: number;
        };
        Returns: SalesTrendPoint[];
      };
      get_top_products: {
        Args: {
          p_days?: number;
          p_limit?: number;
        };
        Returns: TopProduct[];
      };
      get_low_stock_products: {
        Args: {
          p_limit?: number;
        };
        Returns: LowStockProduct[];
      };
      get_stock_summary: {
        Args: Record<PropertyKey, never>;
        Returns: StockSummary;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};
