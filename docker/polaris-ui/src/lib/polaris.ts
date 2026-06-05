export type EndpointKey =
  | 'catalogs'
  | 'principals'
  | 'principalRoles'
  | 'catalogRoles'
  | 'grants'
  | 'namespaces'
  | 'tables'
  | 'principalRoleBindings'
  | 'catalogRoleBindings';

export const endpointMap: Record<EndpointKey, string[]> = {
  catalogs: ['/api/management/v1/catalogs'],
  principals: ['/api/management/v1/principals'],
  principalRoles: ['/api/management/v1/principal-roles'],
  catalogRoles: ['/api/management/v1/catalog-roles'],
  grants: ['/api/management/v1/grants'],
  namespaces: ['/api/catalog/v1/namespaces'],
  tables: ['/api/catalog/v1/tables'],
  principalRoleBindings: ['/api/management/v1/principal-role-bindings'],
  catalogRoleBindings: ['/api/management/v1/catalog-role-bindings']
};

export const readonlyNotice =
  'Read-only viewer: this app only performs GET requests to Polaris endpoints.';

export type PolarisData = {
  endpoint: string;
  status: number;
  data?: unknown;
  error?: string;
};
