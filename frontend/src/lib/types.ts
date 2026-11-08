
export type AnyRecord = Record<string, unknown>;

export interface Variant {
  id: number;
  product: number;
  sku: string;
  price: string | number;
  discounted_price: string | number;
  saved_price?: string | number;
  discount_percentage?: string | number;
  stock: number;
  options?: Record<string, unknown>;
  is_default?: boolean;
  is_active?: boolean;
}

export interface Product {
  id: number;
  name: string;
  slug: string;
  category?: string;
  brand?: string | null;
  description?: string;
  key_feature?: AnyRecord;
  specification?: AnyRecord;
  colors?: string[];
  is_active?: boolean;
  is_featured?: boolean;
  default_variant?: Variant | null;
  variants?: Variant[];
  availability?: string;
}

export interface ProductImage {
  id: number;
  product: number;
  image: string;
  alt_text?: string;
  is_primary?: boolean;
  display_order?: number;
}

export interface Brand {
  id: number;
  name: string;
  slug: string;
  is_active?: boolean;
}

export interface Category {
  id: number;
  name: string;
  slug: string;
  image?: string;
  description?: string;
  filters?: Record<string, string[]>;
  brands?: Brand[];
  sub_categories?: Category[];
  is_featured?: boolean;
}

export interface Page<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export interface User {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  phone?: string;
}

export interface Address {
  id?: number;
  first_name: string;
  last_name: string;
  company?: string;
  address1: string;
  address2?: string;
  city: string;
  postal_code: string;
  country: string;
  region: string;
}

export interface CartItem {
  id: number;
  variant: number;
  product_name: string;
  product_image?: string | null;
  variant_options?: AnyRecord;
  variant_price: string;
  discounted_price: string;
  quantity: number;
}

export interface Cart {
  id: number;
  items: CartItem[];
}

export interface OrderItem {
  id: number;
  variant: number;
  product_name: string;
  sku: string;
  variant_options?: AnyRecord;
  unit_price: string;
  quantity: number;
  line_total: string;
  product_image: string | null;
}

export interface Order {
  id: number;
  shipping_name: string;
  shipping_phone: string;
  shipping_address: string;
  items: OrderItem[];
  subtotal: string;
  discount_amount?: string;
  discount_code?: string;
  total_amount: string;
  status: string;
  payment_status: string;
  created_at: string;
  payment_method: 'sslcommerz' | 'cod';
}

export interface Payment {
  id: number;
  transaction_id: string;
  order: number;
  status: string;
  amount: string;
  currency: string;
  created_at: string;
}

export interface WishlistItem {
  id: number;
  variant_id: number;
  product_id: number;
  product_name: string;
  product_slug: string;
  category: string;
  image?: string | null;
  price: string;
  discounted_price: string;
  stock: number;
  is_available: boolean;
  options?: AnyRecord;
}

export interface Wishlist {
  count: number;
  is_public: boolean;
  items: WishlistItem[];
}

export interface PcVariant {
  id: number;
  product_id: number;
  product_name: string;
  brand: string;
  category: string;
  sku: string;
  price: string;
  discounted_price: string;
  stock: number;
  image?: string | null;
  options?: AnyRecord;
}

export interface PcBuildItem {
  id: number;
  component_type: string;
  variant: PcVariant;
  quantity: number;
  subtotal: string;
}

export interface PcBuild {
  id: number;
  name: string;
  items: PcBuildItem[];
  total_price: string;
}

export interface Compatibility {
  status: string;
  issues: string[];
  warnings: string[];
  missing_required: string[];
  checked_rules: string[];
  note?: string;
}

export interface CompareResult {
  count: number;
  max_products: number;
  products: (
    Product & {
      image?: string;
      variant?: Variant;
      rating?: number;
      review_count?: number;
    }
  )[];
  specification_sections: {
    name: string;
    rows: {
      label: string;
      values: unknown[];
      different: boolean;
    }[];
  }[];
}

export interface ProductQuestion {
  id: number;
  product: number;
  user: number;
  question: string;
  answer: string;
  is_approved: boolean;
  created_at: string;
  updated_at: string;
  user_name?: string;
}

export interface ProductReview {
  id: number;
  product: number;
  user: number;
  rating: number;
  review: string;
  created_at: string;
  updated_at: string;
  user_name?: string;
  is_approved: boolean;
}
