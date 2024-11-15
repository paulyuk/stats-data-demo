#!/usr/bin/env python

import csv
import requests
import argparse


# TODO: we still need to figure out whether or not we want to actually 
#       enter these rows into the DB or not

def upload_file(file_name, file_description, target_url):
    with open(file_name, 'r') as file:
        reader = csv.DictReader(file)
        headers = reader.fieldnames
        
        for row in reader:
            data = {
                "file_name": file_name,
                "file_description": file_description,
                "headers": headers,
                "row": row
            }
            print(row)
            response = requests.post(target_url, json=data)
            if response.status_code != 200:
                print(f"Failed to upload row: {row}")
            else:
                print(f"Successfully uploaded row: {row}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Upload CSV data to a target URL.')
    parser.add_argument('file_name', type=str, help='The name of the file to upload')
    parser.add_argument('file_description', type=str, help='A description of the file')
    parser.add_argument('target_url', type=str, help='The target URL to upload the data to')

    args = parser.parse_args()
    upload_file(args.file_name, args.file_description, args.target_url)