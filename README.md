# WSM File System

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png)](https://githubsfdeploy.herokuapp.com/app/githubdeploy/jcd386/WSM-File-System?ref=main)

A hierarchical file and folder management system for Salesforce, built with Lightning Web Components. Allows users to organize files in nested folder structures anchored to any record (e.g., Account, Opportunity, Case).

## Features

- **Folder Navigation**: Browse nested folder structures with breadcrumb navigation
- **File Management**: Upload, view, move, and delete files
- **Folder Operations**: Create, rename, move, and delete folders (with cascade delete)
- **Drag & Drop Upload**: Drop files directly into folders
- **Cross-Record Navigation**: Navigate folder hierarchies that span related records
- **File Preview**: Click file names to open native Salesforce file preview
- **Folder Templates**: Create reusable folder structure templates and apply them to new records

## Components

### Core Objects

| Object | Description |
|--------|-------------|
| `Folder__c` | Stores folder hierarchy with self-referential parent lookup |
| `File__c` | Stores file references linked to folders |

### Template Objects

| Object | Description |
|--------|-------------|
| `Folder_Template_Set__c` | Groups folder templates together (e.g., "Project Folders", "Case Folders") |
| `Template_Folder__c` | Individual folder templates within a set |

### Apex Classes

| Class | Description |
|-------|-------------|
| `WSMFolderTreeService` | Service class providing all folder/file CRUD operations |

### Lightning Web Components

| Component | Description |
|-----------|-------------|
| `wsmFolderTreeV2` | Folder tree component with full file management functionality |

### Flows

| Flow | Description |
|------|-------------|
| `WSM_ALF_Folders_Build_Folder_Structure` | Auto-launched flow that creates folder structure from a template |

### Permission Set

| Permission Set | Description |
|----------------|-------------|
| `WSM_File_System_Access` | Grants full access to all File System objects and Apex classes |

## Installation

### Option A: One-Click Deploy

Click the **Deploy to Salesforce** button above.

### Option B: Salesforce CLI

```bash
# Clone the repo
git clone https://github.com/jcd386/WSM-File-System.git
cd WSM-File-System

# Deploy to your org
sf project deploy start --target-org YOUR_ORG_ALIAS
```

## Post-Installation Setup

1. **Assign Permission Set**: Go to Setup → Permission Sets → `WSM_File_System_Access` → Manage Assignments → Add users

2. **Add Component to Page**:
   - Go to any record page (e.g., Account)
   - Click the gear icon → Edit Page
   - Drag `wsmFolderTreeV2` onto the page
   - Save and Activate

## Usage

1. Navigate to a record page where the component is placed
2. Click **New Folder** to create folders
3. Click **Upload Files** or drag & drop files into the folder area
4. Click folder names to navigate into them
5. Click file names to preview files
6. Use the action menu (⋮) on each row for:
   - **Files**: Download, View Record, Move File, Delete
   - **Folders**: Rename, Move Folder, Delete

## Configuration

The component uses the `Parent_Id__c` field on `Folder__c` to anchor folders to parent records. This field stores the record ID (Account, Opportunity, etc.) where the folder structure is rooted.

## Folder Templates

The folder template system allows you to define reusable folder structures that can be automatically created on new records.

### Setting Up Templates

1. Create a **Folder Template Set** record (e.g., "Standard Project Folders")
2. Create **Template Folder** records linked to the set, defining your folder hierarchy
3. Use the `Parent_Template_Folder__c` lookup to create nested folder structures

### Applying Templates

Call the `WSM_ALF_Folders_Build_Folder_Structure` flow with these input variables:

| Variable | Description |
|----------|-------------|
| `INC_Folder_Template_Set_Id` | The ID of the Folder Template Set to use |
| `INC_Obj_ID` | The record ID to create folders for (e.g., Account, Opportunity) |
| `INC_Obj_Parent_ID` | (Optional) Parent record ID for cross-record hierarchies |
| `INC_Root_Folder_Name` | Name for the root folder |

Example: Trigger the flow from a record-triggered flow when an Opportunity is created to automatically create a standard folder structure.

## License

MIT

## Author

[We Summit Mountains](https://wesummitmountains.com) - Dallas-based Salesforce Consulting
