--[[
 Behaviour Driven Development for Lua 5.1, 5.2 & 5.3.
 Copyright (C) 2013-2023 Gary V. Vaughan
]]

local gsub = string.gsub

local color = require 'specl.color'
local std = require 'specl.std'
local util = require 'specl.util'

local examplename, indent, nop, strip1st, timesince = 
   util.examplename, util.indent, util.nop, util.strip1st, util.timesince
local empty = std.table.empty


-- Color printing.
local function princ(want_color, ...)
   return print(color(want_color, ...))
end


local function tabulate(descriptions)
   local t = {}
   local s = descriptions[#descriptions]
   local key = gsub(s, '%s*(.-)%s+.*$', '%1')

   if color[key] then
      table.insert(t, color[key])
   end
   s = strip1st(s)
   table.insert(t, s)
   if color[key] then
      table.insert(t, color.reset)
   end
   return table.concat(t)
end


-- Show undisplayed context headers.
local function show_contexts(descriptions, opts)
   local previous, current = opts.previous or {}, {}
   for i = 1, #descriptions - 1 do
      current[i] = descriptions[i]
      if i > #previous or current[i] ~= previous[i] then
         princ(opts.color, indent(current) .. tabulate(current))
         previous = {}
      end
   end
   opts.previous = current
end


local function format_failing_expectation(status, i, exp, verbose)
   if verbose then
      return '   ' ..
         color.strong .. status.filename .. ':' .. status.line .. ':'   ..
         i .. ': ' .. color.reset .. color.fail .. 'FAILED expectation ' ..
         i .. color.reset .. ':\n' .. exp.message
   end

   return '   ' ..
      color.fail .. 'FAILED expectation ' .. i .. color.reset .. ': ' ..
      exp.message
end


local function format_pending_expectation(status, i, exp, verbose)
   local pend = '   '
   if verbose then
      pend = pend ..
         color.strong .. status.filename .. ':' .. status.line .. ':' ..
         i .. ': ' .. color.reset
   end
   pend = pend ..
      color.pend .. 'PENDING expectation ' ..   i .. color.reset .. ': ' ..
      color.warn .. exp.pending .. color.reset

   if exp.status == true then
      pend = '\n' .. pend .. color.warn .. ' passed unexpectedly!' ..
         color.reset .. '\n   ' .. color.strong ..
         "You can safely remove the 'pending()' call from this example." ..
         color.reset
   else
      pend = '\n' .. pend
   end

   return pend
end


local function format_pending_example(message)
   return '(' .. color.pend .. 'PENDING example' .. color.reset ..
      ': ' .. message .. ')'
end


-- Diagnose any failed expectations in situ, and return failure messages
-- for display at the end.
local function format_example(status, descriptions, opts)
   local spaces = indent(descriptions)
   local reports = {fail='', pend=''}
   local counts = {fail=0, pend=0, unexpected=0}

   -- Only show context lines for unfiltered examples.
   show_contexts(descriptions, opts)

   if empty(status.expectations) then
      if status.ispending then
         local pend = format_pending_example(status.ispending)
         princ(opts.color, spaces ..   tabulate(descriptions) ..   pend)
         reports.pend = reports.pend .. pend
      end
   else
      local details = ''

      -- If we have expectations, display the result of each.
      for i, exp in ipairs(status.expectations) do
         if exp.pending ~= nil then
            local pend = format_pending_expectation(status, i, exp, opts.verbose)
            if exp.status == true then
               counts.unexpected = counts.unexpected + 1
            else
               counts.pend = counts.pend + 1
            end
            reports.pend = reports.pend .. pend
            if opts.verbose then
               details = details .. gsub(pend, '^\n', '%0   ')
            end

         elseif exp.status == false then
            counts.fail = counts.fail + 1
            local fail = format_failing_expectation(status, i, exp, opts.verbose)
            reports.fail = reports.fail .. '\n' .. gsub(fail, '\n', '%0   ')
            if opts.verbose then
               details = details .. '\n' .. spaces .. gsub(fail, '\n', '%0   ' .. spaces)
            end
         end
      end

      -- One line summary of abnormal expectations, for non-verbose report format.
      if not opts.verbose then
         details = {}
         if counts.pend > 0 then
            table.insert(details, color.pend .. tostring(counts.pend) .. ' pending')
         end
         if counts.unexpected > 0 then
            table.insert(details, color.warn .. tostring(counts.unexpected) .. ' unexpectedly passing')
         end
         if counts.fail > 0 then
            table.insert(details, color.fail .. tostring(counts.fail) .. ' failing')
         end
         if next(details) then
            details = '(' .. table.concat(details, color.reset .. ', ') .. color.reset .. ')'
         else
            details = ''
         end
      end

      princ(opts.color, spaces .. tabulate(descriptions) ..details)
   end

   -- Add description titles.
   local title = examplename(descriptions)
   title = color.listpre .. color.subhead .. title .. color.listpost
   if reports.pend ~= '' then
      reports.pend = title .. reports.pend .. '\n'
   end
   if reports.fail ~= '' then
      reports.fail = title .. reports.fail .. '\n'
   end

   return reports
end


-- Report statistics.
local function footer(stats, reports, opts)
   local total = stats.pass + stats.fail
   local percent = string.format('%.2f%%', 100 * stats.pass / total)

   print()
   if reports and reports.pend ~= '' then
      princ(opts.color, color.summary .. 'Summary of pending expectations' ..
             color.summarypost)
      princ(opts.color, reports.pend)
   end
   if reports and reports.fail ~= '' then
      princ(opts.color, color.summary .. 'Summary of failed expectations' ..
             color.summarypost)
      princ(opts.color, reports.fail)
   end

   if total > 0 then
      local statcolor = (percent == '100.00%') and color.allpass or color.notallpass
      princ(opts.color, statcolor .. 'Met ' .. percent .. ' of ' .. tostring(total) ..
             ' expectations.')
   else
      princ(opts.color, color.notallpass .. 'No expectations met.')
   end

   local passcolor = (stats.pass > 0) and color.good or color.bad
   local failcolor = (stats.fail > 0) and color.bad or ''
   local pendcolor = (stats.pend > 0) and color.bad or ''
   princ(opts.color, passcolor    .. stats.pass .. ' passed' .. color.reset .. ', ' ..
          pendcolor    .. stats.pend .. ' pending' .. color.reset .. ' and ' ..
          failcolor    .. stats.fail .. ' failed%{reset} in ' ..
          color.clock .. tostring(timesince(stats.starttime)) ..
          ' seconds' .. color.reset .. '.')
end



--[[ ----------------- ]]--
--[[ Public Interface. ]]--
--[[ ----------------- ]]--


local M = {
   header = nop,
   spec = nop,
   expectations = format_example,
   footer = footer,
}

return M
