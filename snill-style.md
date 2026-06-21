# Mobile-First Snill Style Guide for AI Web Apps (Tailwind v4 Native)

## Overview

This style system adapts the Snill design philosophy to mobile-first AI products.

Think:

* AI tools
* Internal tools
* Agent dashboards
* Client portals
* SaaS utilities
* Workflow apps
* Data collection apps
* Automation interfaces

Not:

* Marketing websites
* Landing pages
* Consumer social apps
* Gaming interfaces

The goal is simple:

> Build software that feels trustworthy, obvious, and calm.

Users should immediately understand:

1. What this tool does
2. What they should do next
3. What the AI is currently doing

No decoration should compete with utility.

---

# Core Design Principles

## 1. Prioritize Function Over Brand

The interface is the brand.

Avoid:

* Hero graphics
* Illustrations
* Abstract AI imagery
* Decorative gradients

Use:

* Real data
* Real workflows
* Real outputs
* Real states

The UI should feel like a tool.

---

# 2. Mobile First Always

Design for:

```text
375px
390px
430px
```

first.

Only then scale upward.

Every screen should work comfortably with one thumb.

---

# 3. One Primary Action Per Screen

Good:

```text
Create Agent
```

Bad:

```text
Create Agent
Import Agent
Clone Agent
Templates
Settings
Marketplace
```

The next step should always be obvious.

---

# Layout System

## App Container

Default mobile width:

```html
<div class="mx-auto max-w-md">
```

For slightly wider apps:

```html
<div class="mx-auto max-w-lg">
```

Avoid:

```html
max-w-7xl
```

Most AI tools don't need it.

---

# Screen Padding

Default:

```html
px-4
```

Comfortable:

```html
px-5
```

Rare:

```html
px-6
```

---

# Vertical Rhythm

Default spacing:

```html
space-y-6
```

Major sections:

```html
space-y-8
```

Large screens:

```html
space-y-10
```

Never create crowded screens.

---

# Color System

Use native Tailwind zinc.

Background:

```html
bg-white
```

Secondary surfaces:

```html
bg-zinc-50
```

Text:

```html
text-zinc-950
text-zinc-700
text-zinc-500
```

Borders:

```html
border-zinc-200
```

Success:

```html
text-green-700
bg-green-50
```

Warning:

```html
text-amber-700
bg-amber-50
```

Error:

```html
text-red-700
bg-red-50
```

Avoid colorful interfaces.

Most screens should be 90% neutral colors.

---

# Typography

## Page Title

```html
<h1 class="text-3xl font-semibold tracking-tight">
```

Most screens never need larger.

---

## Section Title

```html
<h2 class="text-xl font-semibold">
```

---

## Labels

```html
<label class="text-sm font-medium">
```

---

## Body Text

```html
<p class="text-sm text-zinc-600">
```

---

## Supporting Text

```html
<p class="text-xs text-zinc-500">
```

---

# App Structure

Most screens should follow:

```text
Header

Primary Action

Content

Status

Navigation
```

Example:

```text
Agent Name

Ask Agent

Conversation

Agent Status

Bottom Navigation
```

---

# Cards

Cards should be subtle.

Base card:

```html
<div
  class="rounded-2xl border border-zinc-200 bg-white p-4"
>
```

Elevated card:

```html
<div
  class="rounded-2xl border border-zinc-200 bg-white p-4 shadow-sm"
>
```

Avoid heavy shadows.

---

# Inputs

Primary text input:

```html
<input
  class="w-full rounded-xl border border-zinc-200 px-4 py-3 outline-none focus:border-zinc-400"
/>
```

Textarea:

```html
<textarea
  class="min-h-32 w-full rounded-xl border border-zinc-200 p-4"
/>
```

Inputs should feel calm and spacious.

---

# Buttons

## Primary

```html
<button
  class="w-full rounded-xl bg-zinc-950 py-3 text-sm font-medium text-white"
>
  Continue
</button>
```

---

## Secondary

```html
<button
  class="w-full rounded-xl border border-zinc-200 py-3 text-sm font-medium"
>
  Cancel
</button>
```

---

## Icon Button

```html
<button
  class="flex h-10 w-10 items-center justify-center rounded-xl border border-zinc-200"
>
```

---

# AI Agent Interface Pattern

Most AI apps should follow this structure.

## User Input

```text
What do you need?
```

↓

## Agent Status

```text
Thinking...
Searching...
Generating...
Reviewing...
```

↓

## Result

```text
Output
```

↓

## Next Action

```text
Approve
Refine
Export
```

Never hide state.

Users should always know what the agent is doing.

---

# Chat Interface

Container:

```html
<div class="space-y-4">
```

User message:

```html
<div
  class="ml-auto max-w-[85%] rounded-2xl bg-zinc-950 p-3 text-white"
>
```

Agent message:

```html
<div
  class="max-w-[85%] rounded-2xl border border-zinc-200 bg-white p-3"
>
```

Avoid chat bubbles with bright colors.

---

# Status Components

## Success

```html
<div
  class="rounded-xl border border-green-200 bg-green-50 p-3"
>
```

---

## Warning

```html
<div
  class="rounded-xl border border-amber-200 bg-amber-50 p-3"
>
```

---

## Error

```html
<div
  class="rounded-xl border border-red-200 bg-red-50 p-3"
>
```

---

# Lists

Simple list:

```html
<div class="divide-y divide-zinc-200">
```

Item:

```html
<div class="py-4">
```

Avoid card overload.

Lists often feel cleaner than grids.

---

# Navigation

## Bottom Navigation

Preferred for mobile apps.

```html
<nav
  class="fixed bottom-0 left-0 right-0 border-t border-zinc-200 bg-white"
>
```

Items:

```html
Home
Agents
Tasks
History
Settings
```

Maximum:

```text
5 items
```

---

# Dashboard Pattern

For AI tools:

```text
Current Status

Today's Tasks

Recent Activity

Actions
```

Not:

```text
20 KPIs
10 charts
6 widgets
```

Most users want action, not analytics.

---

# Empty States

Always include:

1. Explanation
2. Example
3. Action

Example:

```text
No agents yet.

Create your first agent to automate repetitive work.

[Create Agent]
```

---

# Loading States

Use skeletons.

```html
animate-pulse
```

Avoid spinners for long-running AI tasks.

Show progress whenever possible.

Good:

```text
Searching sources...
```

Better:

```text
Searching 24 documents...
```

---

# Motion

Keep motion minimal.

Hover:

```html
transition-colors
```

Cards:

```html
transition-all duration-200
```

Avoid:

* Parallax
* Floating effects
* Animated gradients
* AI-themed particles

---

# AI UX Rules

## Always Show Status

Bad:

```text
Waiting...
```

Good:

```text
Analyzing customer feedback...
```

---

## Show Work

Bad:

```text
Done
```

Good:

```text
Found 12 matching invoices
Generated summary
Created export
```

---

## Make Outputs Actionable

Bad:

```text
Analysis Complete
```

Good:

```text
Export Report
Share Result
Create Task
```

Every AI result should lead somewhere.

---

# Tailwind Cheatsheet

## App Container

```html
mx-auto max-w-md px-4
```

## Page Layout

```html
space-y-8
```

## Card

```html
rounded-2xl border border-zinc-200 bg-white p-4
```

## Input

```html
w-full rounded-xl border border-zinc-200 px-4 py-3
```

## Primary Button

```html
w-full rounded-xl bg-zinc-950 py-3 text-white
```

## Secondary Button

```html
w-full rounded-xl border border-zinc-200 py-3
```

## Page Title

```html
text-3xl font-semibold tracking-tight
```

## Section Title

```html
text-xl font-semibold
```

## Body Text

```html
text-sm text-zinc-600
```

---

# Final Design Prompt

Design a mobile-first AI web application using only Tailwind v4 native utility classes.

Characteristics:

* Mobile-first
* White background
* Zinc palette
* Rounded corners
* Thin borders
* Minimal shadows
* Calm typography
* Spacious spacing
* Single primary action per screen
* Agent status visibility
* Real outputs over decoration
* Documentation-inspired UI
* Internal-tool aesthetic
* No gradients
* No glassmorphism
* No neon colors
* No futuristic AI visuals

The interface should feel like:

"A tool built by operators for operators."

