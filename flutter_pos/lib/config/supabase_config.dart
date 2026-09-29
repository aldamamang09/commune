class SupabaseConfig {
  // Configurable credentials - can be overridden via environment or local preferences
  static String supabaseUrl = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static String supabaseAnonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Centralized Admin API endpoint so Admin Panel and Flutter POS always share the exact same database
  static String adminApiBaseUrl = const String.fromEnvironment(
    'ADMIN_API_URL',
    defaultValue: 'https://ais-dev-w65xuz5vdarxrabrzdphs7-601909081982.asia-southeast1.run.app',
  );

  static const List<String> fallbackApiBaseUrls = [
    'https://ais-dev-w65xuz5vdarxrabrzdphs7-601909081982.asia-southeast1.run.app',
    'https://ais-pre-w65xuz5vdarxrabrzdphs7-601909081982.asia-southeast1.run.app',
    'http://localhost:3000',
    'http://10.0.2.2:3000',
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
