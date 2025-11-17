# Angora API Complete Documentation

## Overview
This document provides comprehensive documentation for all Angora API endpoints used in the EisenVault Flutter application. Each endpoint includes request/response formats, headers, and curl examples.

## Base Configuration

### Base URL Structure
```
{baseUrl}/api/{endpoint}
```

### Common Headers
```http
Accept: application/json
Content-Type: application/json
Accept-Language: en
x-portal: web|mobile
Authorization: {token}
x-service-name: {service_name}
x-customer-hostname: {hostname}
```

## Authentication

### Login
**Endpoint:** `POST /api/auth/login`

**Headers:**
```http
Content-Type: application/json
x-service-name: service-auth
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password"
}
```

**Response:**
```json
{
  "status": 200,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "user_id",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe"
    }
  }
}
```

**Curl Example:**
```bash
curl -X POST "https://your-angora-instance.com/api/auth/login" \
  -H "Content-Type: application/json" \
  -H "x-service-name: service-auth" \
  -d '{
    "email": "user@example.com",
    "password": "password"
  }'
```

## Browse Operations

### Get Departments (Root Level)
**Endpoint:** `GET /api/departments?slim=true`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-portal: web
```

**Response:**
```json
{
  "status": 200,
  "data": [
    {
      "id": "dept_id",
      "name": "Department Name",
      "is_department": true,
      "can_have_children": true,
      "updated_at": "2024-01-01T00:00:00Z",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

**Curl Example:**
```bash
curl -X GET "https://your-angora-instance.com/api/departments?slim=true" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-portal: web"
```

### Get Department Children
**Endpoint:** `GET /api/departments/{departmentId}/children?page={page}&limit={limit}`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-portal: web
```

**Response:**
```json
{
  "status": 200,
  "data": [
    {
      "id": "item_id",
      "name": "Item Name",
      "is_department": false,
      "is_folder": true,
      "can_have_children": true,
      "updated_at": "2024-01-01T00:00:00Z",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

**Curl Example:**
```bash
curl -X GET "https://your-angora-instance.com/api/departments/dept_id/children?page=1&limit=25" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-portal: web"
```

### Get Folder Children
**Endpoint:** `GET /api/folders/{folderId}/children?page={page}&limit={limit}`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-portal: web
```

**Response:**
```json
{
  "status": 200,
  "data": [
    {
      "id": "file_id",
      "name": "document.pdf",
      "is_folder": false,
      "file_type": "pdf",
      "content_type": "application/pdf",
      "updated_at": "2024-01-01T00:00:00Z",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

**Curl Example:**
```bash
curl -X GET "https://your-angora-instance.com/api/folders/folder_id/children?page=1&limit=25" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-portal: web"
```

### Get Item Details
**Endpoint:** `GET /api/files/{fileId}` or `GET /api/folders/{folderId}` or `GET /api/departments/{departmentId}`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-portal: web
```

**Response:**
```json
{
  "status": 200,
  "data": {
    "id": "item_id",
    "name": "Item Name",
    "is_department": false,
    "is_folder": true,
    "description": "Item description",
    "updated_at": "2024-01-01T00:00:00Z",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_by_name": "User Name",
    "created_by_name": "User Name"
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-angora-instance.com/api/files/file_id" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-portal: web"
```

## Document Operations

### Get Document Download Link
**Endpoint:** `GET /api/files/{documentId}/download`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
Accept: application/json, text/plain, */*
Accept-Language: en
referer: https://binod.angorastage.in/nodes
```

**Response:**
```json
{
  "status": 200,
  "data": {
    "download_link": "https://storage.example.com/files/document.pdf"
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-angora-instance.com/api/files/document_id/download" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "Accept: application/json, text/plain, */*" \
  -H "Accept-Language: en" \
  -H "referer: https://binod.angorastage.in/nodes"
```

## Upload Operations

### Upload Small File
**Endpoint:** `POST /api/uploads`

**Headers:**
```http
Authorization: {token}
x-start-byte: 0
x-file-size: {file_size}
x-relative-path: ""
x-file-id: {file_id}
x-parent-id: {parent_folder_id}
x-resumable: true
x-file-name: {file_name}
x-portal: mobile
```

**Request Body:** Multipart form data with file content

**Response:**
```json
{
  "status": 200,
  "data": {
    "id": "upload_id",
    "message": "Upload successful"
  }
}
```

**Curl Example:**
```bash
curl -X POST "https://your-angora-instance.com/api/uploads" \
  -H "Authorization: {token}" \
  -H "x-start-byte: 0" \
  -H "x-file-size: 1024" \
  -H "x-relative-path: \"\"" \
  -H "x-file-id: file_123" \
  -H "x-parent-id: parent_folder_id" \
  -H "x-resumable: true" \
  -H "x-file-name: document.pdf" \
  -H "x-portal: mobile" \
  -F "file=@document.pdf" \
  -F "comment=File description"
```

### Upload Chunk (Large Files)
**Endpoint:** `POST /api/uploads`

**Headers:**
```http
Authorization: {token}
x-file-id: {file_id}
x-file-name: {file_name}
x-start-byte: {start_byte}
x-file-size: {total_file_size}
x-resumable: true
x-relative-path: ""
x-parent-id: {parent_folder_id}
x-portal: mobile
```

**Request Body:** Multipart form data with chunk content

**Response:**
```json
{
  "status": 200,
  "data": {
    "id": "upload_id",
    "uploaded_bytes": 1024
  }
}
```

**Curl Example:**
```bash
curl -X POST "https://your-angora-instance.com/api/uploads" \
  -H "Authorization: {token}" \
  -H "x-file-id: file_123" \
  -H "x-file-name: large_document.pdf" \
  -H "x-start-byte: 1024" \
  -H "x-file-size: 1048576" \
  -H "x-resumable: true" \
  -H "x-relative-path: \"\"" \
  -H "x-parent-id: parent_folder_id" \
  -H "x-portal: mobile" \
  -F "file=@chunk.bin"
```

### Check Upload Status
**Endpoint:** `GET /api/uploads/{fileId}/status`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
```

**Response:**
```json
{
  "status": 200,
  "data": {
    "uploaded_bytes": 1024,
    "total_bytes": 1048576
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-angora-instance.com/api/uploads/file_123/status" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file"
```

## Search Operations

### Search Files and Folders
**Endpoint:** `GET /api/search?name={name}&limit={limit}&page={page}&sort={sort}&direction={direction}`

**Headers:**
```http
Authorization: {token}
x-service-name: service-search
x-portal: mobile
```

**Query Parameters:**
- `name` (required): Search query string
- `limit` (optional): Number of results per page (default: 50)
- `page` (optional): Page number (1-based, default: 1)
- `sort` (optional): Sort field (e.g., "name", "updatedAt", "createdBy")
- `direction` (optional): Sort direction ("asc" or "desc", default: "asc")

**Response:**
```json
{
  "status": 200,
  "meta": {
    "current_page": 1,
    "items_per_page": 8,
    "total_pages": 132,
    "total_records": 1049,
    "has_more": true
  },
  "data": [
    {
      "id": "item_id",
      "raw_file_name": "Search Result",
      "description": "Item description",
      "is_department": false,
      "is_folder": true,
      "is_file": false,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "parent_path": "//path//to//parent//",
      "materialize_path": "//full//path//to//item",
      "data_entry": [
        {
          "metadata": "metadata_id",
          "name": "Title",
          "value": "Search Result",
          "id": "entry_id"
        }
      ],
      "highlight": {
        "_title": ["<highlight>Search</highlight> Result"],
        "content": ["Content with <highlight>search</highlight> term"]
      }
    }
  ],
  "notifications": [],
  "errors": []
}
```

**Curl Example:**
```bash
curl -X GET "https://your-angora-instance.com/api/search?name=document&limit=50&page=1&sort=name&direction=asc" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-search" \
  -H "x-portal: mobile"
```

**Notes:**
- The `data` field is directly an array of results (not wrapped in a `results` object)
- Each result item uses `raw_file_name` for the display name
- Item type is determined by boolean flags: `is_folder`, `is_file`, `is_department`
- The `highlight` field contains search term highlighting when available
- Pagination uses `page` (1-based) instead of `skip`

## Delete Operations

### Delete Files
**Endpoint:** `DELETE /api/files?ids={comma_separated_file_ids}`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-portal: mobile
x-customer-hostname: {hostname}
```

**Response:**
```json
{
  "status": 200,
  "notifications": "Files deleted successfully"
}
```

**Curl Example:**
```bash
curl -X DELETE "https://your-angora-instance.com/api/files?ids=file1,file2,file3" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-portal: mobile" \
  -H "x-customer-hostname: your-hostname.com"
```

### Delete Folders
**Endpoint:** `DELETE /api/folders?ids={comma_separated_folder_ids}`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-portal: mobile
```

**Response:**
```json
{
  "status": 200,
  "notifications": "Folders deleted successfully"
}
```

**Curl Example:**
```bash
curl -X DELETE "https://your-angora-instance.com/api/folders?ids=folder1,folder2" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-portal: mobile"
```

### Delete Departments
**Endpoint:** `DELETE /api/departments?ids={comma_separated_department_ids}`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-portal: mobile
x-customer-hostname: {hostname}
```

**Response:**
```json
{
  "status": 200,
  "notifications": "Departments deleted successfully"
}
```

**Curl Example:**
```bash
curl -X DELETE "https://your-angora-instance.com/api/departments?ids=dept1,dept2" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-portal: mobile" \
  -H "x-customer-hostname: your-hostname.com"
```

### Delete File Version
**Endpoint:** `DELETE /api/files/{fileId}/versions/{versionId}`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-portal: mobile
x-customer-hostname: {hostname}
```

**Response:**
```json
{
  "status": 200,
  "notifications": "Version deleted successfully"
}
```

**Curl Example:**
```bash
curl -X DELETE "https://your-angora-instance.com/api/files/file_id/versions/version_id" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-portal: mobile" \
  -H "x-customer-hostname: your-hostname.com"
```

### Delete Trash Items
**Endpoint:** `DELETE /api/trashes?ids={comma_separated_trash_ids}`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-portal: mobile
x-customer-hostname: {hostname}
x-locale: en
```

**Response:**
```json
{
  "status": 200,
  "notifications": "Trash items deleted successfully"
}
```

**Curl Example:**
```bash
curl -X DELETE "https://your-angora-instance.com/api/trashes?ids=trash1,trash2" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-portal: mobile" \
  -H "x-customer-hostname: your-hostname.com" \
  -H "x-locale: en"
```

## Rename Operations

### Rename File
**Endpoint:** `PUT /api/files/{fileId}`

**Headers:**
```http
Authorization: {token}
x-portal: mobile
x-customer-hostname: {hostname}
```

**Request Body:**
```json
{
  "name": "new_file_name.pdf"
}
```

**Response:**
```json
{
  "status": 200,
  "data": {
    "id": "file_id",
    "name": "new_file_name.pdf"
  }
}
```

**Curl Example:**
```bash
curl -X PUT "https://your-angora-instance.com/api/files/file_id" \
  -H "Authorization: {token}" \
  -H "x-portal: mobile" \
  -H "x-customer-hostname: your-hostname.com" \
  -H "Content-Type: application/json" \
  -d '{"name": "new_file_name.pdf"}'
```

### Rename Folder
**Endpoint:** `PUT /api/folders/{folderId}`

**Headers:**
```http
Authorization: {token}
x-portal: mobile
x-customer-hostname: {hostname}
```

**Request Body:**
```json
{
  "name": "new_folder_name"
}
```

**Response:**
```json
{
  "status": 200,
  "data": {
    "id": "folder_id",
    "name": "new_folder_name"
  }
}
```

**Curl Example:**
```bash
curl -X PUT "https://your-angora-instance.com/api/folders/folder_id" \
  -H "Authorization: {token}" \
  -H "x-portal: mobile" \
  -H "x-customer-hostname: your-hostname.com" \
  -H "Content-Type: application/json" \
  -d '{"name": "new_folder_name"}'
```

### Rename Department
**Endpoint:** `PUT /api/departments/{departmentId}`

**Headers:**
```http
Authorization: {token}
x-portal: mobile
x-customer-hostname: {hostname}
```

**Request Body:**
```json
{
  "name": "new_department_name"
}
```

**Response:**
```json
{
  "status": 200,
  "data": {
    "id": "department_id",
    "name": "new_department_name"
  }
}
```

**Curl Example:**
```bash
curl -X PUT "https://your-angora-instance.com/api/departments/department_id" \
  -H "Authorization: {token}" \
  -H "x-portal: mobile" \
  -H "x-customer-hostname: your-hostname.com" \
  -H "Content-Type: application/json" \
  -d '{"name": "new_department_name"}'
```

## Permission Operations

### Get Node Permissions
**Endpoint:** `GET /api/nodes/{nodeId}/permissions`

**Headers:**
```http
Authorization: {token}
x-service-name: service-file
x-customer-hostname: {hostname}
```

**Response:**
```json
{
  "status": 200,
  "data": {
    "view_document": true,
    "edit_document_content": true,
    "create_document": true,
    "delete_document": true,
    "can_edit": true,
    "can_view": true,
    "can_delete": true
  }
}
```

**Curl Example:**
```bash
curl -X GET "https://your-angora-instance.com/api/nodes/node_id/permissions" \
  -H "Authorization: {token}" \
  -H "x-service-name: service-file" \
  -H "x-customer-hostname: your-hostname.com"
```

## Error Responses

### Authentication Error
```json
{
  "status": 401,
  "message": "Authentication failed"
}
```

### Permission Error
```json
{
  "status": 403,
  "message": "Insufficient permissions"
}
```

### Not Found Error
```json
{
  "status": 404,
  "message": "Resource not found"
}
```

### Server Error
```json
{
  "status": 500,
  "message": "Internal server error"
}
```

## Notes

1. **Pagination**: Angora uses page-based pagination with `page` and `limit` parameters
2. **File Upload**: Large files are uploaded in chunks with resumable capability
3. **Headers**: The `x-portal` header can be set to `web` or `mobile` depending on the client
4. **Customer Hostname**: Required for certain operations, extracted from the base URL
5. **Service Names**: Different operations use different service names (`service-file`, `service-auth`, `service-search`)
6. **Token Format**: Bearer token format is used for authentication
7. **CORS**: Web downloads may require CORS proxy for browser compatibility 