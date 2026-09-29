class SupabaseConfig {
  // Connected directly to the centralized Commune Coffee Supabase database
  static String supabaseUrl = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vidzkzpvgqdwfdfcduti.supabase.co',
  );

  static String supabaseAnonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpZHprenB2Z3Fkd2ZkZmNkdXRpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MDY0ODQ4NSwiZXhwIjoyMTA2MjI0NDg1fQ.kzD5tVzpQs0Ayg_MJrCbNLML3Zn5P62dbf2y9kzUx_M',
  );

  static String supabasePublishableKey = const String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_u4ai7ETWwcpMh6iDFiUaTA_g1t-dg_P',
  );

  // Optional Admin API endpoint fallback
  static String adminApiBaseUrl = const String.fromEnvironment(
    'ADMIN_API_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const List<String> fallbackApiBaseUrls = [
    'http://localhost:3000',
  ];

  // Exact Supabase table names matching the web app & migrations
  static const String tablePosState = 'pos_state';
  static const String tableStaffUsers = 'staff_users';
  static const String tableMenuCategories = 'menu_categories';
  static const String tableMenuItems = 'menu_items';
  static const String tablePromotions = 'promotions';
  static const String tableInventoryItems = 'inventory_items';
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';
  static const String tableUsageLogs = 'usage_logs';
  static const String tableRestocks = 'restocks';
  static const String tableCostings = 'costings';
  static const String tableCostingIngredients = 'costing_ingredients';
  static const String tableRecipes = 'recipes';
  static const String tableRecipeCostings = 'recipe_costings';
  static const String tableRecipeCostingMenuItems = 'recipe_costing_menu_items';
  static const String tableRecipeCostingIngredients = 'recipe_costing_ingredients';
  static const String tableLoginActivity = 'login_activity';
  static const String tableOffRequests = 'off_requests';
  static const String tableVoidRequests = 'void_requests';

  // Exact Postgres RPC function names
  static const String rpcCreateOrderAtomic = 'create_order_atomic';
  static const String rpcVoidOrderAtomic = 'void_order_atomic';
  static const String rpcDeleteOrderAtomic = 'delete_order_atomic';
  static const String rpcCreateRestockAtomic = 'create_restock_atomic';
  static const String rpcEditRestockAtomic = 'edit_restock_atomic';
  static const String rpcDeleteRestockAtomic = 'delete_restock_atomic';
  static const String rpcApproveVoidRequestAtomic = 'approve_void_request_atomic';
  static const String rpcSaveCosting = 'save_costing';
  static const String rpcSaveRecipeCosting = 'save_recipe_costing';
  static const String rpcRenameMenuCategory = 'rename_menu_category';

  static const String posStateId = 'commune-coffee';
}
