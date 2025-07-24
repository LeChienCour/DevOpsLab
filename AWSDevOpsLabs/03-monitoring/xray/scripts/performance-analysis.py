#!/usr/bin/env python3
"""
AWS X-Ray Performance Analysis Script

This script analyzes X-Ray traces to identify performance bottlenecks
and generate performance reports.
"""

import argparse
import boto3
import json
import datetime
import statistics
from collections import defaultdict
from tabulate import tabulate
from botocore.exceptions import ClientError

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Analyze AWS X-Ray performance data')
    parser.add_argument('--region', default=None, help='AWS region')
    parser.add_argument('--time-range', default='1h', help='Time range (e.g., 15m, 1h, 1d)')
    parser.add_argument('--service', help='Filter by service name')
    parser.add_argument('--limit', type=int, default=100, help='Maximum number of traces to analyze')
    parser.add_argument('--output', choices=['table', 'json'], default='table', help='Output format')
    parser.add_argument('--report-type', choices=['service', 'endpoint', 'subsegment'], default='service', 
                        help='Type of performance report to generate')
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

def analyze_service_performance(traces):
    """Analyze performance by service"""
    service_stats = defaultdict(lambda: {'durations': [], 'error_count': 0, 'count': 0})
    
    for trace in traces:
        segments = trace.get('Segments', [])
        
        for segment in segments:
            segment_doc = json.loads(segment.get('Document', '{}'))
            name = segment_doc.get('name', 'Unknown')
            start_time = segment_doc.get('start_time', 0)
            end_time = segment_doc.get('end_time', 0)
            
            if start_time and end_time:
                duration = end_time - start_time
                service_stats[name]['durations'].append(duration)
                service_stats[name]['count'] += 1
                
                if segment_doc.get('error', False) or segment_doc.get('fault', False):
                    service_stats[name]['error_count'] += 1
    
    # Calculate statistics
    results = []
    for service, stats in service_stats.items():
        durations = stats['durations']
        if durations:
            avg_duration = statistics.mean(durations)
            p95_duration = sorted(durations)[int(len(durations) * 0.95)] if len(durations) >= 20 else max(durations)
            max_duration = max(durations)
            error_rate = (stats['error_count'] / stats['count']) * 100 if stats['count'] > 0 else 0
            
            results.append({
                'service': service,
                'count': stats['count'],
                'avg_duration': avg_duration,
                'p95_duration': p95_duration,
                'max_duration': max_duration,
                'error_count': stats['error_count'],
                'error_rate': error_rate
            })
    
    # Sort by average duration (descending)
    results.sort(key=lambda x: x['avg_duration'], reverse=True)
    
    return results

def analyze_endpoint_performance(traces):
    """Analyze performance by endpoint"""
    endpoint_stats = defaultdict(lambda: {'durations': [], 'error_count': 0, 'count': 0})
    
    for trace in traces:
        segments = trace.get('Segments', [])
        
        for segment in segments:
            segment_doc = json.loads(segment.get('Document', '{}'))
            
            # Look for HTTP request data
            http = segment_doc.get('http', {})
            request = http.get('request', {})
            method = request.get('method', 'UNKNOWN')
            url = request.get('url', 'UNKNOWN')
            
            if method != 'UNKNOWN' and url != 'UNKNOWN':
                endpoint = f"{method} {url}"
                start_time = segment_doc.get('start_time', 0)
                end_time = segment_doc.get('end_time', 0)
                
                if start_time and end_time:
                    duration = end_time - start_time
                    endpoint_stats[endpoint]['durations'].append(duration)
                    endpoint_stats[endpoint]['count'] += 1
                    
                    if segment_doc.get('error', False) or segment_doc.get('fault', False):
                        endpoint_stats[endpoint]['error_count'] += 1
    
    # Calculate statistics
    results = []
    for endpoint, stats in endpoint_stats.items():
        durations = stats['durations']
        if durations:
            avg_duration = statistics.mean(durations)
            p95_duration = sorted(durations)[int(len(durations) * 0.95)] if len(durations) >= 20 else max(durations)
            max_duration = max(durations)
            error_rate = (stats['error_count'] / stats['count']) * 100 if stats['count'] > 0 else 0
            
            results.append({
                'endpoint': endpoint,
                'count': stats['count'],
                'avg_duration': avg_duration,
                'p95_duration': p95_duration,
                'max_duration': max_duration,
                'error_count': stats['error_count'],
                'error_rate': error_rate
            })
    
    # Sort by average duration (descending)
    results.sort(key=lambda x: x['avg_duration'], reverse=True)
    
    return results

def analyze_subsegment_performance(traces):
    """Analyze performance by subsegment"""
    subsegment_stats = defaultdict(lambda: {'durations': [], 'error_count': 0, 'count': 0})
    
    for trace in traces:
        segments = trace.get('Segments', [])
        
        for segment in segments:
            segment_doc = json.loads(segment.get('Document', '{}'))
            service = segment_doc.get('name', 'Unknown')
            
            # Process subsegments
            subsegments = segment_doc.get('subsegments', [])
            for subsegment in subsegments:
                name = subsegment.get('name', 'Unknown')
                subseg_id = f"{service}:{name}"
                start_time = subsegment.get('start_time', 0)
                end_time = subsegment.get('end_time', 0)
                
                if start_time and end_time:
                    duration = end_time - start_time
                    subsegment_stats[subseg_id]['durations'].append(duration)
                    subsegment_stats[subseg_id]['count'] += 1
                    
                    if subsegment.get('error', False) or subsegment.get('fault', False):
                        subsegment_stats[subseg_id]['error_count'] += 1
    
    # Calculate statistics
    results = []
    for subseg_id, stats in subsegment_stats.items():
        durations = stats['durations']
        if durations:
            avg_duration = statistics.mean(durations)
            p95_duration = sorted(durations)[int(len(durations) * 0.95)] if len(durations) >= 20 else max(durations)
            max_duration = max(durations)
            error_rate = (stats['error_count'] / stats['count']) * 100 if stats['count'] > 0 else 0
            
            results.append({
                'subsegment': subseg_id,
                'count': stats['count'],
                'avg_duration': avg_duration,
                'p95_duration': p95_duration,
                'max_duration': max_duration,
                'error_count': stats['error_count'],
                'error_rate': error_rate
            })
    
    # Sort by average duration (descending)
    results.sort(key=lambda x: x['avg_duration'], reverse=True)
    
    return results

def print_service_performance_table(results):
    """Print service performance in table format"""
    headers = ["Service", "Count", "Avg Duration", "P95 Duration", "Max Duration", "Error Rate"]
    rows = []
    
    for result in results:
        rows.append([
            result['service'],
            result['count'],
            format_duration(result['avg_duration']),
            format_duration(result['p95_duration']),
            format_duration(result['max_duration']),
            f"{result['error_rate']:.2f}% ({result['error_count']})"
        ])
    
    print(tabulate(rows, headers=headers, tablefmt="grid"))

def print_endpoint_performance_table(results):
    """Print endpoint performance in table format"""
    headers = ["Endpoint", "Count", "Avg Duration", "P95 Duration", "Max Duration", "Error Rate"]
    rows = []
    
    for result in results:
        rows.append([
            result['endpoint'],
            result['count'],
            format_duration(result['avg_duration']),
            format_duration(result['p95_duration']),
            format_duration(result['max_duration']),
            f"{result['error_rate']:.2f}% ({result['error_count']})"
        ])
    
    print(tabulate(rows, headers=headers, tablefmt="grid"))

def print_subsegment_performance_table(results):
    """Print subsegment performance in table format"""
    headers = ["Subsegment", "Count", "Avg Duration", "P95 Duration", "Max Duration", "Error Rate"]
    rows = []
    
    for result in results:
        rows.append([
            result['subsegment'],
            result['count'],
            format_duration(result['avg_duration']),
            format_duration(result['p95_duration']),
            format_duration(result['max_duration']),
            f"{result['error_rate']:.2f}% ({result['error_count']})"
        ])
    
    print(tabulate(rows, headers=headers, tablefmt="grid"))

def main():
    """Main function"""
    args = parse_args()
    
    # Create X-Ray client
    xray_client = boto3.client('xray', region_name=args.region)
    
    # Parse time range
    start_time, end_time = parse_time_range(args.time_range)
    
    # Build filter expression
    filter_expression = build_filter_expression(args)
    
    print(f"Analyzing X-Ray performance data from {start_time.strftime('%Y-%m-%d %H:%M:%S')} to {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    if filter_expression:
        print(f"Filter: {filter_expression}")
    
    # Get trace summaries
    trace_summaries = get_trace_summaries(xray_client, start_time, end_time, filter_expression, args.limit)
    
    if not trace_summaries:
        print("No traces found matching the criteria.")
        return
    
    print(f"Found {len(trace_summaries)} traces for analysis.")
    
    # Get trace IDs
    trace_ids = [trace.get('Id') for trace in trace_summaries]
    
    # Get detailed trace information
    trace_details = get_trace_details(xray_client, trace_ids)
    
    # Analyze performance based on report type
    if args.report_type == 'service':
        results = analyze_service_performance(trace_details)
        if args.output == 'json':
            print(json.dumps(results, default=str, indent=2))
        else:
            print("\nService Performance Report:")
            print_service_performance_table(results)
    
    elif args.report_type == 'endpoint':
        results = analyze_endpoint_performance(trace_details)
        if args.output == 'json':
            print(json.dumps(results, default=str, indent=2))
        else:
            print("\nEndpoint Performance Report:")
            print_endpoint_performance_table(results)
    
    elif args.report_type == 'subsegment':
        results = analyze_subsegment_performance(trace_details)
        if args.output == 'json':
            print(json.dumps(results, default=str, indent=2))
        else:
            print("\nSubsegment Performance Report:")
            print_subsegment_performance_table(results)

if __name__ == '__main__':
    main()