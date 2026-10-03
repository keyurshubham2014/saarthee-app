import { PrismaClient } from '@prisma/client';

// Single Prisma client. Only services and lib may import this (ARCHITECTURE.md).
export const prisma = new PrismaClient();
