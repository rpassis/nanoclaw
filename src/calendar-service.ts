/**
 * Calendar Service - Handles calendar operations on the macOS host
 * Processes calendar tasks from the IPC queue
 */
import { spawnSync } from 'child_process';
import path from 'path';

import { logger } from './logger.js';

const CALENDAR_BIN = path.join(process.cwd(), 'host-tools', 'calendar-bin');

export interface CalendarTask {
  type: 'calendar';
  action:
    | 'list'
    | 'today'
    | 'tomorrow'
    | 'calendars'
    | 'add'
    | 'update'
    | 'search'
    | 'delete';
  params?: {
    days?: number;
    title?: string;
    newTitle?: string;
    date?: string;
    time?: string;
    duration?: string;
    notes?: string;
    calendarName?: string;
    query?: string;
  };
}

export interface CalendarResult {
  success: boolean;
  output?: string;
  error?: string;
}

/**
 * Execute a calendar command on the host
 */
export function executeCalendarCommand(task: CalendarTask): CalendarResult {
  try {
    const args: string[] = [task.action];

    // Build arguments array based on action
    switch (task.action) {
      case 'list':
        args.push(String(task.params?.days || 7));
        break;

      case 'today':
      case 'tomorrow':
      case 'calendars':
        // No additional args needed
        break;

      case 'add':
        if (!task.params?.title || !task.params?.date || !task.params?.time) {
          return {
            success: false,
            error: 'Missing required parameters: title, date, time',
          };
        }
        args.push(
          task.params.title,
          task.params.date,
          task.params.time,
          task.params.duration || '1h',
          task.params.notes || '',
          task.params.calendarName || '',
        );
        break;

      case 'update':
        if (!task.params?.title) {
          return { success: false, error: 'Missing event title to update' };
        }
        args.push(task.params.title);
        if (task.params.newTitle) args.push('--title', task.params.newTitle);
        if (task.params.date) args.push('--date', task.params.date);
        if (task.params.time) args.push('--time', task.params.time);
        if (task.params.duration) args.push('--duration', task.params.duration);
        if (task.params.notes !== undefined) args.push('--notes', task.params.notes);
        if (task.params.calendarName) args.push('--calendar', task.params.calendarName);
        break;

      case 'search':
        if (!task.params?.query) {
          return { success: false, error: 'Missing search query' };
        }
        args.push(task.params.query);
        break;

      case 'delete':
        if (!task.params?.title) {
          return { success: false, error: 'Missing event title' };
        }
        args.push(task.params.title);
        break;

      default:
        return { success: false, error: `Unknown action: ${task.action}` };
    }

    logger.info({ action: task.action, args }, 'Executing calendar command');

    const result = spawnSync(CALENDAR_BIN, args, {
      encoding: 'utf-8',
      timeout: 10000,
    });

    if (result.status === 0) {
      return { success: true, output: result.stdout.trim() };
    } else {
      return {
        success: false,
        error: result.stderr.trim() || 'Calendar command failed',
      };
    }
  } catch (err) {
    const error = err as Error;
    logger.error({ err, action: task.action }, 'Calendar command failed');

    return {
      success: false,
      error: error.message || 'Unknown error',
    };
  }
}
