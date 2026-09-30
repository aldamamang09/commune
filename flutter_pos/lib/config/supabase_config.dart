class SupabaseConfig {
  static const String projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mzulfloebacecqzponrk.supabase.co',
  );
  static String get restBaseUrl => '$projectUrl/rest/v1';

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Pm64A_jKuqiMMSs_99UG7A_y7ZKYU1q',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16dWxmbG9lYmFjZWNxenBvbnJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3NDgxMDYsImV4cCI6MjEwNjMyNDEwNn0.UVkz6iPobycK4K9sgXCjAUmXe8myk4fea5SaKM_lsvo',
  );

  static String get supabaseUrl => projectUrl;
  static String get supabaseAnonKey => anonKey;
  static String get supabasePublishableKey => publishableKey;

  static const String adminApiBaseUrl = String.fromEnvironment(
    'POS_API_URL',
    defaultValue: 'https://communecoffee.vercel.app/api/sync',
  );

  static const List<String> fallbackApiBaseUrls = [adminApiBaseUrl];

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
  static const String tableRecipeCostingIngredients =
      'recipe_costing_ingredients';
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
  static const String rpcApproveVoidRequestAtomic =
      'approve_void_request_atomic';
  static const String rpcSaveCosting = 'save_costing';
  static const String rpcSaveRecipeCosting = 'save_recipe_costing';
  static const String rpcRenameMenuCategory = 'rename_menu_category';

  static const String posStateId = 'commune-coffee';
}
