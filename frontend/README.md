# PlayStation Store Frontend

A React-based frontend for the PlayStation Store microservice application.

## Prerequisites

- Node.js 18+
- npm 9+

## Installation

```bash
cd frontend
npm install
```

## Development

```bash
npm run dev
```

The app runs at [http://localhost:3000](http://localhost:3000).

## Environment Variables

Create a `.env` file in the `frontend/` directory to override defaults:

| Variable           | Default                  | Description              |
|--------------------|--------------------------|--------------------------|
| VITE_CATALOG_API   | http://localhost:8001     | Catalog service URL      |
| VITE_USER_API      | http://localhost:8002     | User service URL         |
| VITE_ORDER_API     | http://localhost:8003     | Order service URL        |

## Build

```bash
npm run build
npm run preview
```
