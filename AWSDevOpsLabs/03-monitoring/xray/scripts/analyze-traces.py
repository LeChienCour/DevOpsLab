#!/usr/bin/env python3
"""
AWS X-Ray Trace Analysis Script

This script demonstrates how to analyze X-Ray traces programmatically
using the AWS SDK for Python (Boto3).
"""

import argparse
import boto3
import json
import datetime
from tabulate import tabulate
from botocore.exceptions import ClientError

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Analyze AWS X-Ray traces')
    parser.add_argument('--region', default=None, help='AWS region')
    parser.add_argument('--time-range', default='15m', help='Time range (e.g., 15m, 1h, 1d)')
    parser.add_argument('--service', help='Filter by service name')
    parser.add_argument('--errors-only', action='store_true', help='Show only traces with errors')
    parser.add_argument('--min-duration', type=float, help='Minimum duration in seconds')
    parser.add_argument('--limit', type=int, default=10, help='Maximum number of traces to return')
    parser.add_argument('--output', choices=['table', 'json'], default='table', help='Output format')
    parser.add_argument('--detail', action='store_true', help='Show detailed trace information')
    return parser.parse_args()

def parse_time_range(time_range):
    """Parse time range string into start and end time"""
    now = datetime.datetime.utcnow()
    
    # Parse the time range string
    unit = time_range[-1].lower()
    try:
        value = int(time_range[:-1])
    except ValueError:
        raise ValueError(f"Invalid time range format: {time_range}. Use format like 15m, 1h, 1d")
    
    if unit == 'm':
        delta = datetime.timedelta(minutes=value)
    elif unit == 'h':
        delta = datetime.timedelta(hours=value)
    elif unit == 'd':
        delta = datetime.timedelta(days=value)
    else:
        raise ValueError(f"Invalid time unit: {unit}. Use m (minutes), h (hours), or d (days)")
    
    start_time = now - delta
    
    return start_time, now

def build_filter_expression(args):
    """Build X-Ray filter expression based on arguments"""
    filters = []
    
    if args.service:
        filters.append(f'service("{args.service}")')
    
    if args.errors_only:
        filters.append('error = true')
    
    if args.min_duration:
        filters.append(f'duration >= {args.min_duration}')
    
    return ' AND '.join(filters) if filters else None

def get_trace_summaries(xray_client, start_time, end_time, filter_expression, limit):
    """Get trace summaries from X-Ray"""
    kwargs = {
        'StartTime': start_time,
        'EndTime': end_time,
        'TimeRangeType': 'TraceId',
        'Sampling': False,
        'MaxResults': min(limit, 100)  # API limit is 100
    }
    
    if filter_expression:
        kwargs['FilterExpression'] = filter_expression
    
    try:
        response = xray_client.get_trace_summaries(**kwargs)
        return response.get('TraceSummaries', [])
    except ClientError as e:
        print(f"Error getting trace summaries: {e}")
        return []

def get_trace_details(xray_client, trace_ids):
    """Get detailed trace information"""
    if not trace_ids:
        return []
    
    try:
        response = xray_client.batch_get_traces(TraceIds=trace_ids)
        return response.get('Traces', [])
    except ClientError as e:
        print(f"Error getting trace details: {e}")
        return []

def format_duration(duration):
    """Format duration in seconds to a readable string"""
    if duration < 1:
        return f"{duration * 1000:.2f}ms"
    else:
        return f"{duration:.3f}s"

def print_trace_table(traces):
    """Print traces in table format"""
    headers = ["Trace ID", "Duration", "Response Time", "URLs", "Status", "Time"]
    rows = []
    
    for trace in traces:
        trace_id = trace.get('Id', 'Unknown')
        duration = trace.get('Duration', 0)
        response_time = trace.get('ResponseTime', 0)
        http = trace.get('Http', {})
        urls = http.get('HttpURL', 'N/A')
        status = "Error" if trace.get('Error', False) or trace.get('Fault', False) else "OK"
        timestamp = datetime.datetime.fromtimestamp(trace.get('StartTime', 0)).strftime('%Y-%m-%d %H:%M:%S')
        
        rows.append([
            trace_id,
            format_duration(duration),
            format_duration(response_time),
            urls,
            status,
            timestamp
        ])
    
    print(tabulate(rows, headers=headers, tablefmt="grid"))

def print_trace_details(traces):
    """Print detailed trace information"""
    for i, trace in enumerate(traces):
        if i > 0:
            print("\n" + "=" * 80 + "\n")
        
        trace_id = trace.get('Id', 'Unknown')
        duration = trace.get('Duration', 0)
        segments = trace.get('Segments', [])
        
        print(f"Trace ID: {trace_id}")
        print(f"Duration: {format_duration(duration)}")
        print(f"Segments: {len(segments)}")
        
        for segment in segments:
            segment_doc = json.loads(segment.get('Document', '{}'))
            name = segment_doc.get('name', 'Unknown')
            segment_duration = segment_doc.get('end_time', 0) - segment_doc.get('start_time', 0)
            
            print(f"\n  Segment: {name} ({format_duration(segment_duration)})")
            
            # Print annotations if available
            annotations = segment_doc.get('annotations', {})
            if annotations:
                print("  Annotations:")
                for key, value in annotations.items():
                    print(f"    {key}: {value}")
            
            # Print subsegments if available
            subsegments = segment_doc.get('subsegments', [])
            if subsegments:
                print("  Subsegments:")
                for subsegment in subsegments:
                    subseg_name = subsegment.get('name', 'Unknown')
                    subseg_duration = subsegment.get('end_time', 0) - subsegment.get('start_time', 0)
                    print(f"    {subseg_name} ({format_duration(subseg_duration)})")

def main():
    """Main function"""
    args = parse_args()
    
    # Create X-Ray client
    xray_client = boto3.client('xray', region_name=args.region)
    
    # Parse time range
    start_time, end_time = parse_time_range(args.time_range)
    
    # Build filter expression
    filter_expression = build_filter_expression(args)
    
    print(f"Analyzing X-Ray traces from {start_time.strftime('%Y-%m-%d %H:%M:%S')} to {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    if filter_expression:
        print(f"Filter: {filter_expression}")
    
    # Get trace summaries
    trace_summaries = get_trace_summaries(xray_client, start_time, end_time, filter_expression, args.limit)
    
    if not trace_summaries:
        print("No traces found matching the criteria.")
        return
    
    print(f"Found {len(trace_summaries)} traces.")
    
    if args.output == 'json':
        print(json.dumps(trace_summaries, default=str, indent=2))
    else:
        print_trace_table(trace_summaries)
    
    if args.detail:
        # Get trace IDs
        trace_ids = [trace.get('Id') for trace in trace_summaries]
        
        # Get detailed trace information
        trace_details = get_trace_details(xray_client, trace_ids)
        
        print("\nDetailed Trace Information:")
        print_trace_details(trace_details)

if __name__ == '__main__':
    main()