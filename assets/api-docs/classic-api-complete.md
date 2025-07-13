# Classic/Alfresco API Complete Documentation

## Overview
This document provides comprehensive documentation for all Classic/Alfresco API endpoints used in the EisenVault Flutter application. Each endpoint includes request/response formats, headers, and curl examples.

## Base Configuration

### Base URL Structure
```
{baseUrl}/api/-default-/public/alfresco/versions/1/{endpoint}
```

### Common Headers
```http
Accept: application/json
Content-Type: application/json
Authorization: Basic {base64_credentials} or {token}
```

## Authentication

### Login
**Endpoint:** `POST /api/-default-/public/authentication/versions/1/tickets`

**Headers:**
```http
Authorization: Basic {base64_credentials}
Content-Type: application/json
```

**Request Body:**
```json
{
  "userId": "username",
  "password": "password"
}
```

**Response:**
```json
{
  "entry": {
    "id": "TICKET_1234567890",
    "userId": "username"
  }
}
```

**Curl Example:**
```bash
curl -X POST "https://your-alfresco-instance.com/api/-default-/public/authentication/versions/1/tickets" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "username",
    "password": "password"
  }'
```

### Get User Profile
**Endpoint:** `GET /api/-default-/public/alfresco/versions/1/people/-me-`

**Headers:**
```http
Authorization: Basic {base64_credentials}
```

**Response:**
```json
{
  "entry": {
    "id": "username",
    "firstName": "John",
    "lastName": "Doe",
    "email": "user@example.com",
    "enabled": true,
    "emailNotificationsEnabled": true
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/people/-me-" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)"
```

## Browse Operations

### Get Sites (Root Level)
**Endpoint:** `GET /api/-default-/public/alfresco/versions/1/sites?skipCount={skipCount}&maxItems={maxItems}`

**Headers:**
```http
Authorization: Basic {base64_credentials}
```

**Response:**
```json
{
  "list": {
    "pagination": {
      "count": 2,
      "hasMoreItems": false,
      "totalItems": 2,
      "skipCount": 0,
      "maxItems": 25
    },
    "entries": [
      {
        "entry": {
          "id": "site_id",
          "title": "Site Title",
          "description": "Site description",
          "visibility": "PUBLIC",
          "preset": "site-dashboard",
          "role": "SiteManager"
        }
      }
    ]
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/sites?skipCount=0&maxItems=25" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)"
```

### Get Site Containers
**Endpoint:** `GET /api/-default-/public/alfresco/versions/1/sites/{siteId}/containers?skipCount={skipCount}&maxItems={maxItems}`

**Headers:**
```http
Authorization: Basic {base64_credentials}
```

**Response:**
```json
{
  "list": {
    "pagination": {
      "count": 1,
      "hasMoreItems": false,
      "totalItems": 1,
      "skipCount": 0,
      "maxItems": 25
    },
    "entries": [
      {
        "entry": {
          "id": "container_id",
          "folderId": "documentLibrary",
          "title": "Document Library",
          "description": "Site document library"
        }
      }
    ]
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/sites/site_id/containers?skipCount=0&maxItems=25" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)"
```

### Get Node Children
**Endpoint:** `GET /api/-default-/public/alfresco/versions/1/nodes/{nodeId}/children?include=path,properties,allowableOperations&skipCount={skipCount}&maxItems={maxItems}`

**Headers:**
```http
Authorization: Basic {base64_credentials}
```

**Response:**
```json
{
  "list": {
    "pagination": {
      "count": 2,
      "hasMoreItems": false,
      "totalItems": 2,
      "skipCount": 0,
      "maxItems": 25
    },
    "entries": [
      {
        "entry": {
          "id": "node_id",
          "name": "document.pdf",
          "nodeType": "cm:content",
          "isFolder": false,
          "isFile": true,
          "modifiedAt": "2024-01-01T00:00:00.000+0000",
          "modifiedByUser": {
            "id": "username",
            "displayName": "User Name"
          },
          "allowableOperations": ["delete", "update", "read"]
        }
      }
    ]
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/nodes/node_id/children?include=path,properties,allowableOperations&skipCount=0&maxItems=25" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)"
```

### Get Node Details
**Endpoint:** `GET /api/-default-/public/alfresco/versions/1/nodes/{nodeId}`

**Headers:**
```http
Authorization: Basic {base64_credentials}
Accept: application/json
```

**Response:**
```json
{
  "entry": {
    "id": "node_id",
    "name": "document.pdf",
    "nodeType": "cm:content",
    "isFolder": false,
    "isFile": true,
    "modifiedAt": "2024-01-01T00:00:00.000+0000",
    "modifiedByUser": {
      "id": "username",
      "displayName": "User Name"
    },
    "properties": {
      "cm:description": "Document description"
    },
    "allowableOperations": ["delete", "update", "read"]
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/nodes/node_id" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)" \
  -H "Accept: application/json"
```

## Document Operations

### Get Document Content
**Endpoint:** `GET /api/-default-/public/alfresco/versions/1/nodes/{nodeId}/content`

**Headers:**
```http
Authorization: Basic {base64_credentials}
```

**Response:** Binary file content

**Curl Example:**
```bash
curl -X GET "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/nodes/node_id/content" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)" \
  -o "document.pdf"
```

## Upload Operations

### Upload File
**Endpoint:** `POST /api/-default-/public/alfresco/versions/1/nodes/{parentNodeId}/children`

**Headers:**
```http
Authorization: Basic {base64_credentials}
```

**Request Body:** Multipart form data
- `filedata`: File content
- `name`: File name
- `nodeType`: "cm:content"
- `cm:description`: File description (optional)
- `autoRename`: "true"
- `renditions`: "doclib"

**Response:**
```json
{
  "entry": {
    "id": "new_node_id",
    "name": "uploaded_document.pdf",
    "nodeType": "cm:content",
    "isFolder": false,
    "isFile": true,
    "modifiedAt": "2024-01-01T00:00:00.000+0000",
    "modifiedByUser": {
      "id": "username",
      "displayName": "User Name"
    }
  }
}
```

**Curl Example:**
```bash
curl -X POST "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/nodes/parent_node_id/children" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)" \
  -F "filedata=@document.pdf" \
  -F "name=document.pdf" \
  -F "nodeType=cm:content" \
  -F "cm:description=Uploaded document" \
  -F "autoRename=true" \
  -F "renditions=doclib"
```

## Search Operations

### Search Files and Folders
**Endpoint:** `POST /api/-default-/public/search/versions/1/search`

**Headers:**
```http
Authorization: Basic {base64_credentials}
Content-Type: application/json
```

**Request Body:**
```json
{
  "query": {
    "query": "cm:name:*search_term* OR cm:content:*search_term* OR cm:description:*search_term*",
    "language": "afts"
  },
  "paging": {
    "maxItems": 50,
    "skipCount": 0
  },
  "sort": [
    {
      "type": "FIELD",
      "field": "cm:name",
      "ascending": true
    }
  ],
  "include": ["allowableOperations", "properties", "aspectNames"]
}
```

**Response:**
```json
{
  "list": {
    "pagination": {
      "count": 1,
      "hasMoreItems": false,
      "totalItems": 1,
      "skipCount": 0,
      "maxItems": 50
    },
    "entries": [
      {
        "entry": {
          "id": "node_id",
          "name": "search_result.pdf",
          "nodeType": "cm:content",
          "isFolder": false,
          "isFile": true,
          "modifiedAt": "2024-01-01T00:00:00.000+0000",
          "modifiedByUser": {
            "id": "username",
            "displayName": "User Name"
          },
          "allowableOperations": ["delete", "update", "read"],
          "aspectNames": ["cm:versionable", "cm:auditable"]
        }
      }
    ]
  }
}
```

**Curl Example:**
```bash
curl -X POST "https://your-alfresco-instance.com/api/-default-/public/search/versions/1/search" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "query": "cm:name:*document* OR cm:content:*document* OR cm:description:*document*",
      "language": "afts"
    },
    "paging": {
      "maxItems": 50,
      "skipCount": 0
    },
    "sort": [
      {
        "type": "FIELD",
        "field": "cm:name",
        "ascending": true
      }
    ],
    "include": ["allowableOperations", "properties", "aspectNames"]
  }'
```

## Delete Operations

### Delete Node
**Endpoint:** `DELETE /api/-default-/public/alfresco/versions/1/nodes/{nodeId}`

**Headers:**
```http
Authorization: Basic {base64_credentials}
```

**Response:** 204 No Content

**Curl Example:**
```bash
curl -X DELETE "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/nodes/node_id" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)"
```

### Delete File Version
**Endpoint:** `DELETE /api/-default-/public/alfresco/versions/1/nodes/{nodeId}/versions/{versionId}`

**Headers:**
```http
Authorization: Basic {base64_credentials}
```

**Response:** 204 No Content

**Curl Example:**
```bash
curl -X DELETE "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/nodes/node_id/versions/version_id" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)"
```

### Delete Trash Items
**Endpoint:** `DELETE /api/-default-/public/alfresco/versions/1/deleted-nodes`

**Headers:**
```http
Authorization: Basic {base64_credentials}
Content-Type: application/json
```

**Request Body:**
```json
{
  "nodeIds": ["node1", "node2", "node3"]
}
```

**Response:** 204 No Content

**Curl Example:**
```bash
curl -X DELETE "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/deleted-nodes" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)" \
  -H "Content-Type: application/json" \
  -d '{
    "nodeIds": ["node1", "node2", "node3"]
  }'
```

## Rename Operations

### Rename Node
**Endpoint:** `PUT /api/-default-/public/alfresco/versions/1/nodes/{nodeId}`

**Headers:**
```http
Authorization: Basic {base64_credentials}
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "new_name.pdf"
}
```

**Response:**
```json
{
  "entry": {
    "id": "node_id",
    "name": "new_name.pdf",
    "nodeType": "cm:content",
    "isFolder": false,
    "isFile": true,
    "modifiedAt": "2024-01-01T00:00:00.000+0000",
    "modifiedByUser": {
      "id": "username",
      "displayName": "User Name"
    }
  }
}
```

**Curl Example:**
```bash
curl -X PUT "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/nodes/node_id" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)" \
  -H "Content-Type: application/json" \
  -d '{"name": "new_name.pdf"}'
```

## Permission Operations

### Get Node with Permissions
**Endpoint:** `GET /api/-default-/public/alfresco/versions/1/nodes/{nodeId}?include=allowableOperations`

**Headers:**
```http
Authorization: Basic {base64_credentials}
```

**Response:**
```json
{
  "entry": {
    "id": "node_id",
    "name": "document.pdf",
    "nodeType": "cm:content",
    "isFolder": false,
    "isFile": true,
    "modifiedAt": "2024-01-01T00:00:00.000+0000",
    "modifiedByUser": {
      "id": "username",
      "displayName": "User Name"
    },
    "allowableOperations": ["delete", "update", "read", "create"]
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-alfresco-instance.com/api/-default-/public/alfresco/versions/1/nodes/node_id?include=allowableOperations" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)"
```

## Error Responses

### Authentication Error
```json
{
  "error": {
    "errorKey": "framework.exception.ApiDefault",
    "statusCode": 401,
    "briefSummary": "40140100 Authentication failed",
    "descriptionURL": "https://api-explorer.alfresco.com",
    "logId": "1234567890"
  }
}
```

### Permission Error
```json
{
  "error": {
    "errorKey": "framework.exception.ApiDefault",
    "statusCode": 403,
    "briefSummary": "40340300 Access Denied",
    "descriptionURL": "https://api-explorer.alfresco.com",
    "logId": "1234567890"
  }
}
```

### Not Found Error
```json
{
  "error": {
    "errorKey": "framework.exception.ApiDefault",
    "statusCode": 404,
    "briefSummary": "40440400 Not Found",
    "descriptionURL": "https://api-explorer.alfresco.com",
    "logId": "1234567890"
  }
}
```

### Server Error
```json
{
  "error": {
    "errorKey": "framework.exception.ApiDefault",
    "statusCode": 500,
    "briefSummary": "50050000 Internal Server Error",
    "descriptionURL": "https://api-explorer.alfresco.com",
    "logId": "1234567890"
  }
}
```

## Notes

1. **Authentication**: Classic/Alfresco uses Basic Authentication with base64-encoded credentials
2. **Pagination**: Uses `skipCount` and `maxItems` parameters for pagination
3. **Node Types**: Different node types include `cm:content` (files), `cm:folder` (folders), `st:site` (sites)
4. **Permissions**: Permissions are returned in the `allowableOperations` array
5. **File Upload**: Single file uploads only, no chunked upload support
6. **Search**: Uses AFTS (Alfresco Full Text Search) language for queries
7. **Sites**: Sites are the top-level organizational units in Alfresco
8. **Containers**: Sites contain containers like "documentLibrary"
9. **Versions**: File versioning is supported through dedicated endpoints
10. **Trash**: Deleted items go to trash and can be permanently deleted 